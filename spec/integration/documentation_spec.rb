# frozen_string_literal: true

require "spec_helper"
require "open3"
require "uri"
require "tmpdir"
require "yaml"
require "rubygems/package"

RSpec.describe "documentation and package contents" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:package) { Gem::Specification.load(File.join(root, "ruby_llm-browser.gemspec")) }

  it "includes the hosted documentation link in the built gem metadata" do
    Dir.mktmpdir("browser-documentation-metadata-") do |directory|
      artifact = File.join(directory, "ruby_llm-browser.gem")
      Gem::Package.build(package, false, false, artifact)
      published_specification = Gem::Package.new(artifact).spec
      documentation_url = YAML.load_file(File.join(root, "docs/_config.yml")).fetch("url")

      expect(published_specification.metadata["documentation_uri"]).to eq(documentation_url)
    end
  end

  it "ships every public guide, example, migration template and required notice" do
    expected = %w[
      README.md CHANGELOG.md LICENSE.txt NOTICE.md SECURITY.md CONTRIBUTING.md CODE_OF_CONDUCT.md
      docs/README.md docs/API.md docs/RAILS.md docs/SECURITY_MODEL.md docs/RELEASING.md
      docs/_reference/api-and-configuration.md docs/_reference/roadmap.md
      docs/_advanced/rails-integration.md docs/_advanced/result-delivery.md
      docs/_core_features/diagnostics.md docs/_reference/whats-new-in-0-2.md
      docs/_getting_started/whats-new-in-0-3.md
      docs/RELEASE_AUDIT.md docs/WORK.md docs/SPEC_BASELINE.md
      examples/plain_ruby.rb examples/rails_adapter.rb examples/rails_results.rb
      lib/generators/ruby_llm/browser/templates/create_ruby_llm_browser_tables.rb.tt
    ]
    expect(package.files).to include(*expected)
    expect(package.files.grep(/(?:\.sqlite3|\.env|\.gem$|\.lock$|spec\/)/)).to be_empty
    expect(package.files.grep(%r{\A(?:dev/|test/|gemfiles/|docs/evidence/)})).to be_empty
  end

  it "resolves local Markdown links inside the distributed package" do
    package.files.grep(/\.md$/).each do |file|
      File.read(File.join(root, file)).scan(/\[[^\]]*\]\(([^)]+)\)/).flatten.each do |link|
        jekyll_target = link.match(/\A\{% link (.+?) %\}\z/)&.captures&.first
        generated_site_url = link.match?(/\A\{\{.*\|\s*relative_url\s*\}\}\z/)
        next if generated_site_url
        next if !jekyll_target && link.start_with?("#", "https://", "http://", "mailto:")

        relative = if jekyll_target
          File.join("docs", jekyll_target)
        else
          target = URI::DEFAULT_PARSER.unescape(link.split("#").first)
          File.expand_path(target, File.dirname(File.join(root, file))).delete_prefix("#{root}/")
        end
        present = package.files.include?(relative) || package.files.any? { |path| path.start_with?("#{relative.chomp("/")}/") }
        expect(present).to be(true), "#{file}: target not shipped: #{link}"
      end
    end
  end

  it "runs each marked offline README example with all HTTP blocked" do
    snippets = File.read(File.join(root, "README.md")).scan(/```ruby\n(.*?)```/m).flatten
                   .select { |source| source.include?("# smoke-test: offline") }
    expect(snippets).not_to be_empty
    snippets.each do |source|
      blocked = 'require "webmock"; WebMock.enable!; WebMock.disable_net_connect!;'
      stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-I", File.join(root, "lib"), "-e", "#{blocked}\n#{source}")
      expect(status).to be_success, stderr
      expect(stdout).to include("ok", "Example")
    end
  end
end
