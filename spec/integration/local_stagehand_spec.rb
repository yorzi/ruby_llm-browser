# frozen_string_literal: true

require "spec_helper"
require "stagehand"

# SDK feasibility contracts, not the unsupported adapter or an actual local server.
RSpec.describe "local Stagehand SDK contract" do
  let(:endpoint) { "http://127.0.0.1:49991" }
  let(:client) do
    Stagehand::Client.new(server: :local, base_url: "http://127.0.0.1:49990",
                         browserbase_api_key: "", model_api_key: "", max_retries: 0, timeout: 1)
  end
  let(:manager) { client.instance_variable_get(:@local_server_manager) }
  let(:browser) { { type: :local, cdp_url: "ws://127.0.0.1:49992/devtools/browser/fixture" } }

  before do
    # Intercept the SDK's process boundary, not its HTTP serializer. No binary runs.
    allow(manager).to receive(:ensure_running).and_return(endpoint)
    allow(manager).to receive(:close)
  end

  after { client.close }

  def json(body)
    { status: 200, headers: { "Content-Type" => "application/json" }, body: JSON.generate(body) }
  end

  it "serializes an existing local CDP browser without Browserbase credentials or launch options" do
    request = stub_request(:post, "#{endpoint}/v1/sessions/start").with do |http|
      body = JSON.parse(http.body)
      body == { "modelName" => "fixture-model", "browser" => { "type" => "local", "cdpUrl" => browser[:cdp_url] },
                "selfHeal" => false, "verbose" => 0 } && !http.headers.key?("X-Bb-Api-Key")
    end.to_return(json(success: true, data: { available: true, sessionId: "local-fixture" }))

    response = client.sessions.start(model_name: "fixture-model", browser: browser, self_heal: false, verbose: 0)

    expect(response.data.session_id).to eq("local-fixture")
    expect(request).to have_been_requested.once
  end

  it "requires an explicit local browser type to avoid the Browserbase default" do
    expect { client.sessions.start(model_name: "fixture-model") }
      .to raise_error(ArgumentError, /Browserbase credentials/)
    expect(manager).not_to have_received(:ensure_running)
    expect(a_request(:any, %r{/v1/sessions/start})).not_to have_been_made
  end

  it "uses the SDK-managed endpoint even when another local base URL was supplied" do
    request = stub_request(:post, "#{endpoint}/v1/sessions/start")
      .to_return(json(success: true, data: { available: true, sessionId: "local-fixture" }))

    client.sessions.start(model_name: "fixture-model", browser: browser)

    expect(manager).to have_received(:ensure_running).once
    expect(request).to have_been_requested.once
    expect(a_request(:any, %r{127\.0\.0\.1:49990})).not_to have_been_made
  end

  it "accepts navigation with no final URL so the host must obtain independent provenance" do
    stub_request(:post, "#{endpoint}/v1/sessions/local-fixture/navigate")
      .to_return(json(success: true, data: { result: nil }))

    response = client.sessions.navigate("local-fixture", url: "http://127.0.0.1:49993/redirect")

    expect(response.success).to be(true)
    expect(response.data.result).to be_nil
  end

  it "returns only an acknowledgement from end, without proving browser termination" do
    request = stub_request(:post, "#{endpoint}/v1/sessions/local-fixture/end")
      .to_return(json(success: true))

    response = client.sessions.end_("local-fixture")

    expect(response.to_h).to eq(success: true)
    expect(request).to have_been_requested.once
  end

  it "does not retry a lost local start response" do
    request = stub_request(:post, "#{endpoint}/v1/sessions/start").to_timeout

    expect { client.sessions.start(model_name: "fixture-model", browser: browser) }
      .to raise_error(Stagehand::Errors::APIConnectionError)
    expect(request).to have_been_requested.once
  end
end
