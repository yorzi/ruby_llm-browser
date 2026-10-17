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
end
