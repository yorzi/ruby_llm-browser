# frozen_string_literal: true

require "spec_helper"
require "open3"
require "tmpdir"

RSpec.describe "worker death recovery" do
  it "reaps a persisted fake session after the worker is killed before ensure" do
    root = File.expand_path("../..", __dir__)
    script = File.join(root, "spec/fixtures/worker_recovery.rb")
    Dir.mktmpdir("browser-worker") do |directory|
      database = File.join(directory, "worker.sqlite3")
      _, stderr, killed = Open3.capture3(RbConfig.ruby, "-I", File.join(root, "lib"), script, "crash", database)
      expect(killed).to be_signaled, stderr
      expect(killed.termsig).to eq(Signal.list.fetch("KILL"))

      stdout, stderr, recovered = Open3.capture3(RbConfig.ruby, "-I", File.join(root, "lib"), script, "recover", database)
      expect(recovered).to be_success, stderr
      expect(stdout).to include("PASS killed worker recovered")
    end
  end
end
