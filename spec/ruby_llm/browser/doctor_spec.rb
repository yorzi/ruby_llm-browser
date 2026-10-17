# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::Doctor do
  subject(:report) { described_class.new(backend: backend, env: env).report }

  let(:backend) { RubyLLM::Browser::FakeBackend.new }
  let(:env) { {} }

  it "passes for a qualified fake backend with no environment overrides" do
    expect(report[:ok]).to be(true)
    expect(report[:summary]).to eq("ready for a qualified live session")
    names = report[:checks].map { |check| check[:name] }
    expect(names).to include(:ruby_llm, :stagehand, :egress_isolation)
  end

  it "blocks when the backend does not assert enforced egress" do
    unqualified = RubyLLM::Browser::FakeBackend.new(
      capabilities: RubyLLM::Browser::Capabilities.new(server_mode: :fake, egress_isolation: :unverified)
    )
    report = described_class.new(backend: unqualified, env: env).report

    expect(report[:ok]).to be(false)
    expect(report[:summary]).to include("blocked: egress_isolation")
  end

  it "warns about a base URL override the SDK would otherwise honour" do
    report = described_class.new(backend: backend, env: { "STAGEHAND_API_URL" => "https://evil.test" }).report
    check = report[:checks].find { |item| item[:name] == :base_url_override }

    expect(check[:status]).to be(:warn)
    expect(check[:detail]).to include("STAGEHAND_API_URL")
  end

  it "fails when preset custom headers are not host-approved" do
    headers = RubyLLM::Browser::FakeBackend.new(
      capabilities: RubyLLM::Browser::Capabilities.new(
        server_mode: :fake, egress_isolation: :enforced, custom_headers_present: true
      )
    )
    report = described_class.new(backend: headers, env: env).report
    expect(report[:checks].find { |item| item[:name] == :custom_headers }[:status]).to be(:fail)
  end

  it "fails for unpinned local mode" do
    local = RubyLLM::Browser::FakeBackend.new(
      capabilities: RubyLLM::Browser::Capabilities.new(
        server_mode: :local, egress_isolation: :enforced
      )
    )
    report = described_class.new(backend: local, env: env).report
    expect(report[:checks].find { |item| item[:name] == :local_binary }[:status]).to be(:fail)
  end

  it "reports credential presence without ever printing a value" do
    secret = "sk-super-secret-value"
    report = described_class.new(backend: backend,
                                 env: { "BROWSERBASE_API_KEY" => secret, "MODEL_API_KEY" => secret }).report
    check = report[:checks].find { |item| item[:name] == :credentials }

    expect(check[:status]).to be(:info)
    expect(report.to_s).not_to include(secret)
  end

  it "warns when credentials are absent" do
    check = report[:checks].find { |item| item[:name] == :credentials }
    expect(check[:status]).to be(:warn)
  end
end
