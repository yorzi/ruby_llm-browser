# frozen_string_literal: true

require "spec_helper"
require "open3"
require "tmpdir"

RSpec.describe "durable host result example" do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:blocked) { File.join(root, "spec/fixtures/block_http.rb") }

  def run_fixture(mode, database, queue_file)
    Open3.capture3({ "RUBYOPT" => "#{ENV['RUBYOPT']} -r#{blocked}" }, RbConfig.ruby,
                   "-I", File.join(root, "lib"), File.join(root, "spec/fixtures/result_recovery.rb"),
                   mode, database, queue_file)
  end

  it "retrieves a schema-checked result after a separate Active Job worker exits" do
    example = File.join(root, "examples/rails_results.rb")
    stdout, stderr, status = Open3.capture3({ "RUBYOPT" => "#{ENV['RUBYOPT']} -r#{blocked}" }, RbConfig.ruby,
                                           "-I", File.join(root, "lib"), "-e",
                                           "require #{example.dump}; BrowserResultsExample.run_demo")
    expect(status).to be_success, stderr
    expect(stdout).to include("RESULT_AFTER_WORKER_EXIT_PASS", "SCOPED_READS_PASS", "IDEMPOTENT_WRITE_PASS")
  end

  %w[before-write after-write].each do |mode|
    it "recovers #{mode} failure without repeating browser execution, then reads after exit" do
      Dir.mktmpdir("browser-delivery-") do |directory|
        database, queue = %w[host.sqlite3 job.json].map { |name| File.join(directory, name) }
        _, stderr, status = run_fixture("prepare", database, queue)
        expect(status).to be_success, stderr
        stdout, stderr, status = run_fixture(mode, database, queue)
        expect(status).to be_success, stderr
        expect(stdout).to include("DELIVERY_ONLY_RECOVERY_PASS")
        stdout, stderr, status = run_fixture("read", database, queue)
        expect(status).to be_success, stderr
        expect(stdout).to include("DURABLE_RECOVERY_PASS")
      end
    end
  end

  it "exposes the crash gap without replaying a closed browser operation" do
    Dir.mktmpdir("browser-delivery-crash-") do |directory|
      database, queue = %w[host.sqlite3 job.json].map { |name| File.join(directory, name) }
      _, stderr, status = run_fixture("prepare", database, queue)
      expect(status).to be_success, stderr
      _, stderr, status = run_fixture("crash", database, queue)
      expect(status).to be_signaled, stderr
      expect(status.termsig).to eq(Signal.list.fetch("KILL"))
      stdout, stderr, status = run_fixture("lost-result", database, queue)
      expect(status).to be_success, stderr
      expect(stdout).to include("CRASH_GAP_NO_REPLAY_PASS")
    end
  end
end
