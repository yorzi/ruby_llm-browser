# frozen_string_literal: true

require "spec_helper"
require "open3"

# FR-06 / FR-08: the Rails adapter is opt-in and must load only when required, defining
# the durable store, job and reaper without touching a database or provider config.
RSpec.describe "requiring ruby_llm/browser/rails" do
  def run_ruby(script)
    root = File.expand_path("../..", __dir__)
    Open3.capture3(RbConfig.ruby, "-I", File.join(root, "lib"), "-e", script, chdir: root)
  end

  it "loads the ActiveRecord adapter and Active Job components" do
    script = <<~RUBY
      require "ruby_llm/browser/rails"
      puts "ADAPTER=" + RubyLLM::Browser::Rails.name
      puts "STORE=" + RubyLLM::Browser::Rails::ActiveRecordOperationStore.name
      puts "JOB=" + RubyLLM::Browser::Rails::OperationJob.name
      puts "REAPER=" + RubyLLM::Browser::Rails::Reaper.name
      puts "CORE=" + RubyLLM::Browser::Inspect.name
    RUBY

    stdout, stderr, status = run_ruby(script)

    expect(status).to be_success, "ruby exited #{status.exitstatus}: #{stderr}"
    expect(stdout).to include("ADAPTER=RubyLLM::Browser::Rails")
    expect(stdout).to include("STORE=RubyLLM::Browser::Rails::ActiveRecordOperationStore")
    expect(stdout).to include("JOB=RubyLLM::Browser::Rails::OperationJob")
    expect(stdout).to include("REAPER=RubyLLM::Browser::Rails::Reaper")
    expect(stdout).to include("CORE=RubyLLM::Browser::Inspect")
  end
end
