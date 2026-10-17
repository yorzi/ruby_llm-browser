# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::Inspect do
  subject(:tool) { described_class.new(context: context) }

  let(:backend) { RubyLLM::Browser::FakeBackend.new }
  let(:store) { RubyLLM::Browser::InMemoryOperationStore.new }
  let(:context) { build_context(backend: backend, operation_store: store) }

  let(:url) { "https://docs.example.com/a" }

  it "declares a stable model-facing name" do
    expect(tool.name).to eq("browser_inspect")
    expect(described_class.tool_name).to eq("browser_inspect")
  end

  it "exposes only url, instruction and max_bytes, with url required" do
    schema = tool.parameters_schema
    expect(schema["properties"].keys).to contain_exactly("url", "instruction", "max_bytes")
    expect(schema["required"]).to eq([ "url" ])
  end

  it "returns a model-safe, bounded observation for an allowed page" do
    result = tool.call(url: url)

    expect(result[:status]).to eq("ok")
    expect(result[:data]).to eq(RubyLLM::Browser::FakeBackend::DEFAULT_OBSERVE)
    expect(result[:final_url]).to eq(url)
    expect(result[:operation_id]).to start_with("op_")
  end

  it "turns a typed denial into a safe error hash instead of raising" do
    result = tool.call(url: "http://localhost/admin")

    expect(result[:status]).to eq("error")
    expect(result[:error][:code]).to eq("NOT_AUTHORIZED")
    expect(backend.call_count(:start)).to eq(0)
  end

  it "returns the stable code for an unqualified backend" do
    unqualified = RubyLLM::Browser::FakeBackend.new(
      capabilities: RubyLLM::Browser::Capabilities.new(server_mode: :fake, egress_isolation: :unverified)
    )
    result = described_class.new(context: build_context(backend: unqualified)).call(url: url)

    expect(result[:status]).to eq("error")
    expect(result[:error][:code]).to eq("UNSUPPORTED_SECURITY_CAPABILITY")
  end

  it "never leaves a live session or secret in the result" do
    result = tool.call(url: url).to_s
    expect(result).not_to match(/cdp|ws:|cookie|api[-_]?key/i)
  end

  it "requires a host Context and never invents one" do
    expect { described_class.new(context: nil) }
      .to raise_error(RubyLLM::Browser::InvalidInput, /context/)
    expect { described_class.new(context: :fake) }
      .to raise_error(RubyLLM::Browser::InvalidInput, /context/)
  end

  it "loads and runs in plain Ruby with no Rails constant" do
    expect(defined?(Rails)).to be_nil
    expect(tool.call(url: url)[:status]).to eq("ok")
  end
end
