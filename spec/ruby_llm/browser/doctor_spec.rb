# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::Doctor do
  subject(:report) { described_class.new(backend: backend, env: env).report }

  let(:backend) { RubyLLM::Browser::FakeBackend.new }
  let(:env) { {} }
  let(:stagehand) do
    RubyLLM::Browser::StagehandBackend.new(
      browserbase_api_key: "bb-test-key", model_api_key: "model-test-key",
      model_name: "openai/gpt-4o-mini", env: env
    )
  end

  it "passes for a qualified fake backend with no environment overrides" do
    expect(report[:ok]).to be(true)
    expect(report[:summary]).to eq("configuration checks passed; live provider guarantees are not verified")
    names = report[:checks].map { |check| check[:name] }
    expect(report[:mode]).to eq(:offline)
    expect(names).to contain_exactly(:ruby_llm, :egress_isolation)
    expect(report[:checks].map { |check| check[:status] }).to all(eq(:pass))
  end

  it "does not inspect provider environment variables for an offline backend" do
    unreadable_env = Object.new
    def unreadable_env.[](_key) = raise("provider environment was read")
    offline = described_class.new(backend: backend, env: unreadable_env).report

    expect(offline[:ok]).to be(true)
    expect(backend.calls).to be_empty
    expect(offline[:checks].find { |item| item[:name] == :egress_isolation }[:detail]).to include("FakeBackend")
  end

  it "identifies an unconfigured backend without unrelated SDK or credential warnings" do
    missing = described_class.new(env: {}).report

    expect(missing[:mode]).to eq(:unconfigured)
    expect(missing[:ok]).to be(false)
    expect(missing[:checks].map { |item| item[:name] }).to contain_exactly(:ruby_llm, :egress_isolation)
  end

  it "does not require Stagehand credentials for a custom live backend" do
    custom = Class.new(RubyLLM::Browser::Backend) do
      def capabilities
        RubyLLM::Browser::Capabilities.new(egress_isolation: :enforced)
      end
    end.new
    custom_report = described_class.new(backend: custom, env: {}).report

    expect(custom_report[:mode]).to eq(:live)
    expect(custom_report[:ok]).to be(true)
    expect(custom_report[:summary]).to include("live provider guarantees are not verified")
    expect(custom_report[:checks].map { |item| item[:name] }).to contain_exactly(:ruby_llm, :egress_isolation)
  end

  it "blocks when the backend does not assert enforced egress" do
    unqualified = RubyLLM::Browser::FakeBackend.new(
      capabilities: RubyLLM::Browser::Capabilities.new(server_mode: :fake, egress_isolation: :unverified)
    )
    report = described_class.new(backend: unqualified, env: env).report

    expect(report[:ok]).to be(false)
    expect(report[:summary]).to include("blocked: egress_isolation")
  end

  it "reports Stagehand as unsupported even when its SDK is installed" do
    report = described_class.new(backend: stagehand, env: env).report
    check = report[:checks].find { |item| item[:name] == :egress_isolation }

    expect(report[:ok]).to be(false)
    expect(check[:status]).to be(:fail)
    expect(check[:detail]).to include("unsupported")
    expect(report[:mode]).to eq(:live)
    expect(report[:checks].map { |item| item[:name] }).to include(:stagehand, :credentials)
  end

  it "warns about a base URL override the SDK would otherwise honour" do
    report = described_class.new(backend: stagehand, env: { "STAGEHAND_API_URL" => "https://evil.test" }).report
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
    report = described_class.new(backend: stagehand,
                                 env: { "BROWSERBASE_API_KEY" => secret, "MODEL_API_KEY" => secret }).report
    check = report[:checks].find { |item| item[:name] == :credentials }

    expect(check[:status]).to be(:info)
    expect(report.to_s).not_to include(secret)
  end

  it "warns when credentials are absent" do
    live_report = described_class.new(backend: stagehand, env: env).report
    check = live_report[:checks].find { |item| item[:name] == :credentials }
    expect(check[:status]).to be(:warn)
  end
end
