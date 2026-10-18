# frozen_string_literal: true

require "spec_helper"
require "open3"

# FR-01 / FR-08: the Gem core must load in plain Ruby without Rails and without
# touching provider configuration. The check runs in a subprocess so it observes the
# real load graph instead of this suite's already-loaded constants.
RSpec.describe "requiring ruby_llm/browser" do
  def root
    File.expand_path("../..", __dir__)
  end

  def run_ruby(script)
    Open3.capture3(RbConfig.ruby, "-I", File.join(root, "lib"), "-e", script, chdir: root)
  end

  it "loads without Rails, Active Job or an API key" do
    script = <<~RUBY
      require "ruby_llm/browser"
      loaded = $LOADED_FEATURES.grep(%r{/(rails|active_job|active_record|railties)/})
      puts "LOADED=" + loaded.inspect
      puts "BROWSER=" + RubyLLM::Browser::VERSION
    RUBY

    stdout, stderr, status = run_ruby(script)

    expect(status).to be_success, "ruby exited #{status.exitstatus}: #{stderr}"
    expect(stdout).to include("LOADED=[]")
    expect(stdout).to include("BROWSER=#{RubyLLM::Browser::VERSION}")
  end

  it "builds the tool pair without provider configuration, SDK loading or dispatch" do
    script = <<~'RUBY'
      require "webmock"
      WebMock.enable!
      WebMock.disable_net_connect!
      require "ruby_llm/browser"
      ENV.singleton_class.prepend(Module.new do
        def [](key)
          raise "provider environment read" if key.match?(/API_KEY|STAGEHAND|BROWSERBASE/)
          super
        end

        def fetch(key, *args, &block)
          raise "provider environment read" if key.match?(/API_KEY|STAGEHAND|BROWSERBASE/)
          super
        end
      end)
      backend = RubyLLM::Browser::FakeBackend.new
      context = RubyLLM::Browser::Context.new(
        actor_id: "test", run_id: "test", backend: backend,
        source_policy: RubyLLM::Browser::Policy.new(allowed_hosts: ["docs.example.com"]),
        operation_store: RubyLLM::Browser::InMemoryOperationStore.new
      )
      tools = RubyLLM::Browser.tools(context: context, schema: {"type" => "object"})
      raise "wrong tools" unless tools.map(&:name) == %w[browser_inspect browser_extract]
      raise "unexpected dispatch" unless backend.calls.empty?
      loaded = $LOADED_FEATURES.grep(%r{/(rails|active_job|active_record|railties|stagehand)/})
      raise "loaded framework or SDK: #{loaded}" unless loaded.empty?
      puts "TOOLS_LOAD_BOUNDARY_PASS"
    RUBY
    stdout, stderr, status = run_ruby(script)

    expect(status).to be_success, stderr
    expect(stdout).to include("TOOLS_LOAD_BOUNDARY_PASS")
  end
end
