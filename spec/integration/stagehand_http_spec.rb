# frozen_string_literal: true

require "spec_helper"
require "stagehand"

RSpec.describe "Stagehand 3.21 HTTP contract" do
  let(:endpoint) { "https://api.stagehand.browserbase.com/v1/sessions" }
  let(:backend) do
    RubyLLM::Browser::StagehandBackend.new(
      browserbase_api_key: "bb-test-credential", model_api_key: "model-test-credential",
      model_name: "openai/gpt-4o-mini"
    )
  end
  let(:operation) { build_operation }
  let(:context) { build_context(backend: backend) }

  def json_response(body)
    { status: 200, headers: { "Content-Type" => "application/json" }, body: JSON.generate(body) }
  end

  def qualify_adapter_for_contract_test
    allow(backend).to receive(:capabilities).and_return(
      RubyLLM::Browser::Capabilities.new(server_mode: :remote, egress_isolation: :enforced)
    )
  end

  it "refuses the Stagehand backend before any provider request by default" do
    expect { RubyLLM::Browser::Engine.new(context: context).inspect(url: "https://docs.example.com/a") }
      .to raise_error(RubyLLM::Browser::UnsupportedSecurityCapability, /egress isolation/)
    expect(a_request(:any, %r{api\.stagehand\.browserbase\.com})).not_to have_been_made
  end

  it "uses the real SDK serializer in a stubbed contract test and leaves cleanup pending" do
    qualify_adapter_for_contract_test
    start = stub_request(:post, "#{endpoint}/start")
      .with(body: hash_including("modelName" => "openai/gpt-4o-mini", "selfHeal" => false,
                                "waitForCaptchaSolves" => false),
            headers: { "x-bb-api-key" => "bb-test-credential", "x-stainless-retry-count" => "0" })
      .to_return(json_response(success: true, data: { sessionId: "sdk-session", cdpUrl: "wss://private-devtools" }))
    stub_request(:post, "#{endpoint}/sdk-session/navigate")
      .to_return(json_response(success: true, data: { result: { url: "https://docs.example.com/a" } }))
    stub_request(:post, "#{endpoint}/sdk-session/observe")
      .to_return(json_response(success: true, data: { result: [] }))
    stub_request(:post, "#{endpoint}/sdk-session/end")
      .to_return(json_response(success: true))

    result = RubyLLM::Browser::Engine.new(context: context).inspect(url: "https://docs.example.com/a")

    expect(result.status).to eq(:cleanup_pending)
    expect(result.to_json).not_to include("private-devtools", "bb-test-credential")
    expect(start).to have_been_requested.once
  end

  it "makes exactly one HTTP request for a 500 start, not SDK retries" do
    qualify_adapter_for_contract_test
    request = stub_request(:post, "#{endpoint}/start").to_return(status: 500, body: "private provider details")

    expect { backend.start(context: context, operation: operation, now: fixed_time) }
      .to raise_error(RubyLLM::Browser::SessionUnknown)
    expect(request).to have_been_requested.once
  end

  it "makes exactly one HTTP request when the start times out" do
    qualify_adapter_for_contract_test
    request = stub_request(:post, "#{endpoint}/start").to_timeout

    expect { backend.start(context: context, operation: operation, now: fixed_time) }
      .to raise_error(RubyLLM::Browser::SessionUnknown)
    expect(request).to have_been_requested.once
  end

  it "tracks and cleans a partial unsuccessful start that returned a session id" do
    qualify_adapter_for_contract_test
    stub_request(:post, "#{endpoint}/start")
      .to_return(json_response(success: false, data: { sessionId: "partial-session", cdpUrl: "wss://private" }))
    cleanup = stub_request(:post, "#{endpoint}/partial-session/end").to_return(json_response(success: true))

    result = RubyLLM::Browser::Engine.new(context: context).inspect(url: "https://docs.example.com/a")

    expect(result.status).to eq(:cleanup_pending)
    expect(context.operation_store.fetch(result.operation_id).session_id).to eq("partial-session")
    expect(cleanup).to have_been_requested.once
  end

  it "keeps a successful HTTP response without a session id unknown" do
    qualify_adapter_for_contract_test
    stub_request(:post, "#{endpoint}/start").to_return(json_response(success: true, data: {}))

    expect { backend.start(context: context, operation: operation, now: fixed_time) }
      .to raise_error(RubyLLM::Browser::SessionUnknown)
  end

  it "never invents final-URL provenance when the SDK navigation result is null" do
    qualify_adapter_for_contract_test
    stub_request(:post, "#{endpoint}/sdk-session/navigate")
      .to_return(json_response(success: true, data: { result: nil }))
    session = RubyLLM::Browser::Session.new(id: "sdk-session")

    expect { backend.navigate(session, url: "https://docs.example.com/a", operation: operation, now: fixed_time) }
      .to raise_error(RubyLLM::Browser::SessionUnknown, /final destination/)
  end

  it "rejects a changed process environment before constructing or calling the SDK" do
    original = ENV["STAGEHAND_CUSTOM_HEADERS"]
    configured = backend
    qualify_adapter_for_contract_test
    begin
      ENV["STAGEHAND_CUSTOM_HEADERS"] = "Authorization: private-injected-value"

      expect { configured.start(context: context, operation: operation, now: fixed_time) }
        .to raise_error(RubyLLM::Browser::UnsupportedSecurityCapability)
    ensure
      original.nil? ? ENV.delete("STAGEHAND_CUSTOM_HEADERS") : ENV["STAGEHAND_CUSTOM_HEADERS"] = original
    end
  end
end
