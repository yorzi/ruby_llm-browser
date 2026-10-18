# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser, ".tools" do
  let(:backend) { RubyLLM::Browser::FakeBackend.new }
  let(:context) { build_context(backend: backend) }
  let(:schema) do
    { "type" => "object", "properties" => { "title" => { "type" => "string" } },
      "required" => [ "title" ], "additionalProperties" => false }
  end
  let(:tools) { described_class.tools(context: context, schema: schema) }

  it "registers only the two read-only tool instances through RubyLLM's public API" do
    isolated = RubyLLM.context { |config| config.openai_api_key = "fixture-not-a-real-key" }
    chat = isolated.chat(model: "gpt-4o-mini", provider: :openai, assume_model_exists: true)
    chat.with_tools(*tools)

    expect(chat.tools.keys).to contain_exactly(:browser_inspect, :browser_extract)
    expect(chat.tools[:browser_inspect]).to equal(tools.first)
    expect(chat.tools[:browser_extract]).to equal(tools.last)
    expect(tools.map(&:context)).to all(equal(context))
    expect(backend.calls).to be_empty
  end

  it "executes both tools and preserves policy and schema behavior" do
    inspect, extract = tools
    expect(inspect.call(url: "https://docs.example.com/")[:status]).to eq("ok")
    result = extract.call(url: "https://docs.example.com/")
    expect(result[:data]).to eq("title" => "Example")
    expect(result[:locator]).to include("scope" => "extract")
    expect(backend.call_count(:start)).to eq(2)
    expect(backend.call_count(:end_session)).to eq(2)
  end

  it "runs the registered tools through RubyLLM's chat tool loop without a model request" do
    isolated = RubyLLM.context { |config| config.openai_api_key = "fixture-not-a-real-key" }
    chat = isolated.chat(model: "gpt-4o-mini", provider: :openai, assume_model_exists: true).with_tools(*tools)
    calls = %w[browser_inspect browser_extract].map do |name|
      RubyLLM::ToolCall.new(id: name, name: name, arguments: { "url" => "https://docs.example.com/" })
    end
    chat.add_message(role: :assistant, content: nil, tool_calls: calls.to_h { |call| [ call.id, call ] })
    chat.run_tools

    responses = chat.messages.select { |message| message.role == :tool }
    expect(responses.size).to eq(2)
    expect(responses.map(&:content).join).to include("Example", "Open the documentation link")
    expect(backend.call_count(:start)).to eq(2)
    expect(backend.call_count(:end_session)).to eq(2)
  end

  it "does not share mutable host schema or tool instances between calls" do
    first = tools
    other = described_class.tools(context: context, schema: schema)
    schema["required"] << "new_field"

    expect(first.last.schema["required"]).to eq([ "title" ])
    expect(other.first).not_to equal(first.first)
    expect(other.last).not_to equal(first.last)
  end

  it "requires the host context and extraction schema" do
    expect { described_class.tools(context: nil, schema: schema) }
      .to raise_error(RubyLLM::Browser::InvalidInput, /context/)
    expect { described_class.tools(context: context, schema: nil) }
      .to raise_error(RubyLLM::Browser::InvalidInput, /host-pinned schema/)
    expect { described_class.tools(context: context) }.to raise_error(ArgumentError, /schema/)
    expect { described_class.tools(schema: schema) }.to raise_error(ArgumentError, /context/)
    expect(backend.calls).to be_empty
  end

  it "rejects an invalid schema at execution before opening a session" do
    _, extract = described_class.tools(context: context, schema: { "type" => "string" })
    result = extract.call(url: "https://docs.example.com/")

    expect(result.dig(:error, :code)).to eq("INVALID_INPUT")
    expect(backend.calls).to be_empty
  end

  it "does not widen destination policy" do
    inspect, extract = tools
    [ inspect, extract ].each do |tool|
      expect(tool.call(url: "https://blocked.example/").dig(:error, :code)).to eq("NOT_AUTHORIZED")
    end
    expect(backend.calls).to be_empty
  end
end
