# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::Extract do
  subject(:tool) { described_class.new(context: context, schema: schema) }

  let(:schema) do
    { "type" => "object", "properties" => { "title" => { "type" => "string" } },
      "required" => [ "title" ] }
  end
  let(:backend) { RubyLLM::Browser::FakeBackend.new }
  let(:context) { build_context(backend: backend) }

  let(:url) { "https://docs.example.com/a" }

  it "declares a stable model-facing name" do
    expect(tool.name).to eq("browser_extract")
  end

  it "keeps the schema host-pinned and out of the model's arguments" do
    expect(tool.schema).to eq(schema)
    expect(tool.parameters_schema["properties"].keys).to contain_exactly("url", "instruction", "max_bytes")
    expect(tool.parameters_schema["required"]).to eq([ "url" ])
  end

  it "requires a host-pinned schema" do
    expect { described_class.new(context: context, schema: nil) }
      .to raise_error(RubyLLM::Browser::InvalidInput, /host-pinned schema/)
  end

  it "extracts bounded JSON against the pinned schema" do
    result = tool.call(url: url)

    expect(result[:status]).to eq("ok")
    expect(result[:data]).to eq(RubyLLM::Browser::FakeBackend::DEFAULT_EXTRACT)
    expect(result[:locator]).to include("scope" => "extract")
    expect(result[:locator]["schema_digest"]).to eq(RubyLLM::Browser::Redactor.digest(schema))
  end

  it "rejects a malicious host schema as a safe error instead of dispatching" do
    bad = described_class.new(context: context,
                              schema: { "type" => "object", "properties" => {}, "evil" => true })
    result = bad.call(url: url)

    expect(result[:status]).to eq("error")
    expect(result[:error][:code]).to eq("INVALID_INPUT")
    expect(backend.call_count(:start)).to eq(0)
  end

  it "rejects a non-object schema" do
    result = described_class.new(context: context, schema: { "type" => "string" }).call(url: url)
    expect(result[:error][:code]).to eq("INVALID_INPUT")
  end

  it "bounds oversized extraction data" do
    big = RubyLLM::Browser::FakeBackend.new(extract: { "title" => "x" * 10_000 })
    result = described_class.new(context: build_context(backend: big), schema: schema)
                            .call(url: url, max_bytes: 256)

    expect(result[:status]).to eq("truncated")
  end
end
