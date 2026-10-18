# frozen_string_literal: true

require "spec_helper"
require "open3"

RSpec.describe "durable store concurrency" do
  it "serializes quota, idempotency, start claims and approval consumption across connections" do
    root = File.expand_path("../..", __dir__)
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-I", File.join(root, "lib"),
                                          File.join(root, "spec/fixtures/concurrent_store.rb"))

    expect(status).to be_success, stderr
    expect(stdout).to include("PASS quota idempotency start approval")
  end
end
