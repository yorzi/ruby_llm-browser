# frozen_string_literal: true

require "spec_helper"
require "open3"
require "uri"

RSpec.describe "documentation and package contents" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:package) { Gem::Specification.load(File.join(root, "ruby_llm-browser.gemspec")) }

  it "ships every public guide, example, migration template and required notice" do
    expected = %w[
      README.md CHANGELOG.md LICENSE.txt NOTICE.md SECURITY.md CONTRIBUTING.md CODE_OF_CONDUCT.md
      docs/README.md docs/API.md docs/RAILS.md docs/SECURITY_MODEL.md docs/RELEASING.md
      docs/RELEASE_AUDIT.md docs/WORK.md docs/SPEC_BASELINE.md
      examples/plain_ruby.rb examples/rails_adapter.rb
      lib/generators/ruby_llm/browser/templates/create_ruby_llm_browser_tables.rb.tt
    ]
    expect(package.files).to include(*expected)
    expect(package.files.grep(/(?:\.sqlite3|\.env|\.gem$|\.lock$|spec\/)/)).to be_empty
  end

  it "resolves local Markdown links inside the distributed package" do
    package.files.grep(/\.md$/).each do |file|
      File.read(File.join(root, file)).scan(/\[[^\]]*\]\(([^)]+)\)/).flatten.each do |link|
        next if link.start_with?("#", "https://", "http://", "mailto:")

        target = URI::DEFAULT_PARSER.unescape(link.split("#").first)
        relative = File.expand_path(target, File.dirname(File.join(root, file))).delete_prefix("#{root}/")
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
