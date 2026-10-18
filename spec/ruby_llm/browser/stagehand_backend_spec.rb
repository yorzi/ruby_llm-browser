# frozen_string_literal: true

require "spec_helper"
require "stagehand"

RSpec.describe RubyLLM::Browser::StagehandBackend do
  subject(:backend) do
    described_class.new(
      browserbase_api_key: "bb-secret-key-1234", model_api_key: "model-secret-key-5678",
      model_name: "openai/gpt-4o-mini", env: env, client: client
    )
  end

  let(:sessions) { instance_spy(Stagehand::Resources::Sessions) }
  let(:client) { instance_double(Stagehand::Client, sessions: sessions) }
  let(:env) { {} }
  let(:now) { Time.utc(2026, 10, 17, 12, 0, 0) }
  let(:context) { instance_double(RubyLLM::Browser::Context, actor_id: "actor-1", run_id: "run-1") }
  let(:operation) { build_operation(id: "op-1") }
  let(:session) { RubyLLM::Browser::Session.new(id: "sess-1", url: "https://docs.example.com/a") }

  def response(data, success = true)
    BrowserSpecSupport::StagehandResponse.new(data, success)
  end

  def data(session_id: nil, cdp_url: nil, result: nil)
    BrowserSpecSupport::StagehandData.new(session_id: session_id, cdp_url: cdp_url, result: result)
  end

  # Test-only subclass exercises the SDK translation behind the production
  # qualification gate. The public StagehandBackend has no qualification switch.
  def qualified_backend_for_contract_test
    adapter_class = Class.new(described_class) do
      def capabilities
        RubyLLM::Browser::Capabilities.new(server_mode: :remote, egress_isolation: :enforced)
      end
    end
    adapter_class.new(
      browserbase_api_key: "bb-secret-key-1234", model_api_key: "model-secret-key-5678",
      model_name: "openai/gpt-4o-mini", env: env, client: client
    )
  end

  it "reports honest capabilities and pinned secrets" do
    expect(backend.capabilities.server_mode).to eq(:remote)
    expect(backend.capabilities.egress_isolation).to eq(:unverified)
    expect(backend.capabilities.act_supported?).to be(false)
    expect(backend.secrets).to contain_exactly("bb-secret-key-1234", "model-secret-key-5678")
  end

  it "never leaks a credential in inspect" do
    expect(backend.inspect).not_to include("secret-key")
  end

  describe "client construction" do
    it "passes every argument explicitly and disables retries" do
      allow(Stagehand::Client).to receive(:new).and_return(client)
      built = described_class.new(
        browserbase_api_key: "bb-secret-key-1234", model_api_key: "model-secret-key-5678",
        model_name: "openai/gpt-4o-mini", env: env
      )

      expect(built.send(:client)).to eq(client)
      expect(Stagehand::Client).to have_received(:new).with(
        browserbase_api_key: "bb-secret-key-1234", model_api_key: "model-secret-key-5678",
        server: "remote", base_url: described_class::DEFAULT_BASE_URL,
        max_retries: 0, timeout: 60.0
      )
    end

    it "ignores STAGEHAND_API_URL / STAGEHAND_BASE_URL overrides" do
      overridden = { "STAGEHAND_API_URL" => "https://evil.test", "STAGEHAND_BASE_URL" => "https://evil.test" }
      built = described_class.new(
        browserbase_api_key: "bb-secret-key-1234", model_api_key: "model-secret-key-5678",
        model_name: "openai/gpt-4o-mini", env: overridden
      )
      expect(built.base_url).to eq(described_class::DEFAULT_BASE_URL)
    end
  end

  describe "#start" do
    it "refuses a live session without any caller override" do
      expect { backend.start(context: context, operation: operation, now: now) }
        .to raise_error(RubyLLM::Browser::UnsupportedSecurityCapability, /unsupported/)
      expect(sessions).not_to have_received(:start)
    end

    it "returns an isolated session and never surfaces the cdp_url in the adapter contract" do
      contract_backend = qualified_backend_for_contract_test
      allow(sessions).to receive(:start)
        .and_return(response(data(session_id: "sess-1", cdp_url: "ws://secret-cdp")))
      result = contract_backend.start(context: context, operation: operation, now: now)

      expect(result.id).to eq("sess-1")
      expect(sessions).to have_received(:start)
        .with(hash_including(model_name: "openai/gpt-4o-mini", request_options: hash_including(max_retries: 0)))
      expect(result.to_h.to_s).not_to match(/cdp|ws:/)
    end

    it "treats an ambiguous start as unknown, not as success" do
      contract_backend = qualified_backend_for_contract_test
      timeout = Stagehand::Errors::APITimeoutError.new(url: URI("https://api.stagehand.browserbase.com"))
      allow(sessions).to receive(:start).and_raise(timeout)
      expect { contract_backend.start(context: context, operation: operation, now: now) }
        .to raise_error(RubyLLM::Browser::SessionUnknown)
    end

    it "treats a 5xx start as unknown and a 4xx start as a provider error" do
      contract_backend = qualified_backend_for_contract_test
      allow(sessions).to receive(:start).and_raise(status_error(500))
      expect { contract_backend.start(context: context, operation: operation, now: now) }
        .to raise_error(RubyLLM::Browser::SessionUnknown)

      allow(sessions).to receive(:start).and_raise(status_error(401))
      expect { contract_backend.start(context: context, operation: operation, now: now) }
        .to raise_error(RubyLLM::Browser::ProviderError, /status 401/)
    end
  end

  it "refuses every Stagehand operation that can issue a live browser request by default" do
    expect { backend.navigate(session, url: "https://docs.example.com/b", operation: operation, now: now) }
      .to raise_error(RubyLLM::Browser::UnsupportedSecurityCapability, /unsupported/)
    expect { backend.observe(session, instruction: nil, operation: operation, now: now) }
      .to raise_error(RubyLLM::Browser::UnsupportedSecurityCapability, /unsupported/)
    expect { backend.extract(session, schema: {}, instruction: nil, operation: operation, now: now) }
      .to raise_error(RubyLLM::Browser::UnsupportedSecurityCapability, /unsupported/)
    expect(sessions).not_to have_received(:navigate)
    expect(sessions).not_to have_received(:observe)
    expect(sessions).not_to have_received(:extract)
  end

  describe "#navigate" do
    it "returns the session at the requested URL" do
      contract_backend = qualified_backend_for_contract_test
      allow(sessions).to receive(:navigate).and_return(response(data(result: { "url" => "https://docs.example.com/b" })))
      moved = contract_backend.navigate(session, url: "https://docs.example.com/b", operation: operation, now: now)

      expect(moved.url).to eq("https://docs.example.com/b")
      expect(sessions).to have_received(:navigate)
        .with("sess-1", hash_including(url: "https://docs.example.com/b"))
    end

    it "uses the provider's final URL when it reports one" do
      contract_backend = qualified_backend_for_contract_test
      allow(sessions).to receive(:navigate)
        .and_return(response(data(result: { "url" => "https://docs.example.com/landed" })))
      moved = contract_backend.navigate(session, url: "https://docs.example.com/b", operation: operation, now: now)
      expect(moved.url).to eq("https://docs.example.com/landed")
    end
  end

  describe "#observe / #extract" do
    it "maps observed candidate actions to plain hashes" do
      contract_backend = qualified_backend_for_contract_test
      action = instance_double(Stagehand::Models::SessionObserveResponse::Data::Result,
                               description: "Open the docs link", selector: "a#docs",
                               method_: "click", arguments: [])
      allow(sessions).to receive(:observe).and_return(response(data(result: [ action ])))

      observed = contract_backend.observe(session, instruction: "the docs link", operation: operation, now: now)
      expect(observed).to eq([
        { "description" => "Open the docs link", "method" => "click", "selector" => "a#docs", "arguments" => [] }
      ])
    end

    it "returns extracted data as plain, string-keyed JSON" do
      contract_backend = qualified_backend_for_contract_test
      allow(sessions).to receive(:extract)
        .and_return(response(data(result: { title: "Hi", tags: [ "a" ] })))

      data = contract_backend.extract(session, schema: {}, instruction: nil, operation: operation, now: now)
      expect(data).to eq("title" => "Hi", "tags" => [ "a" ])
    end

    it "does not retry read-only calls" do
      contract_backend = qualified_backend_for_contract_test
      allow(sessions).to receive(:extract).and_raise(status_error(500))
      expect { contract_backend.extract(session, schema: {}, instruction: nil, operation: operation, now: now) }
        .to raise_error(RubyLLM::Browser::ProviderError)
    end
  end

  describe "#act" do
    it "refuses Act even when the test simulates qualified egress" do
      contract_backend = qualified_backend_for_contract_test
      expect { contract_backend.act(session, action: {}, operation: operation, now: now) }
        .to raise_error(RubyLLM::Browser::UnsupportedSecurityCapability, /Act is disabled/)
      expect(sessions).not_to have_received(:act)
    end
  end

  describe "#end_session" do
    it "does not treat an accepted end request as confirmed closure" do
      allow(sessions).to receive(:end_).and_return(response(nil))
      expect(backend.end_session(session, operation: operation, now: now)).to be(false)
      expect(sessions).to have_received(:end_).once

      allow(sessions).to receive(:end_).and_raise(status_error(500))
      expect(backend.end_session(session, operation: operation, now: now)).to be(false)
    end
  end

  it "cannot prove an unresolved outcome and reports unknown" do
    expect(backend.reconcile(operation, now: now)).to eq(:unknown)
  end

  describe "local mode" do
    it "reports an unpinned binary as unqualified and refuses egress qualification" do
      local = described_class.new(
        browserbase_api_key: "bb-secret-key-1234", model_api_key: "model-secret-key-5678",
        model_name: "openai/gpt-4o-mini", server: :local, env: {}
      )
      expect(local.capabilities.local_mode?).to be(true)
      expect(local.capabilities.local_binary_pinned?).to be(false)
      expect(local.capabilities.egress_isolation).to eq(:unverified)
      expect(RubyLLM::Browser::Policy.new(allowed_hosts: [ "docs.example.com" ])
        .egress_qualified?(local.capabilities)).to be(false)
    end

    it "accepts a host-pinned server binary or version" do
      [ "STAGEHAND_SEA_BINARY", "STAGEHAND_SERVER_VERSION" ].each do |key|
        local = described_class.new(
          browserbase_api_key: "bb-secret-key-1234", model_api_key: "model-secret-key-5678",
          model_name: "openai/gpt-4o-mini", server: :local, env: { key => "pinned" }
        )
        expect(local.capabilities.local_binary_pinned?).to be(true)
      end
    end
  end

  describe "custom headers" do
    it "reports preset headers and refuses qualification unless approved" do
      present = described_class.new(
        browserbase_api_key: "bb-secret-key-1234", model_api_key: "model-secret-key-5678",
        model_name: "openai/gpt-4o-mini", env: { "STAGEHAND_CUSTOM_HEADERS" => "X-Trace: 1" }
      )
      expect(present.capabilities.custom_headers_present?).to be(true)
      qualified = RubyLLM::Browser::Policy.new(allowed_hosts: [ "docs.example.com" ])
      expect(qualified.egress_qualified?(present.capabilities)).to be(false)

      approved = described_class.new(
        browserbase_api_key: "bb-secret-key-1234", model_api_key: "model-secret-key-5678",
        model_name: "openai/gpt-4o-mini",
        custom_headers_approved: true, env: { "STAGEHAND_CUSTOM_HEADERS" => "X-Trace: 1" }
      )
      expect(approved.capabilities.custom_headers_approved?).to be(true)
      expect(qualified.egress_qualified?(approved.capabilities)).to be(false)
    end
  end

  def status_error(status)
    Stagehand::Errors::APIStatusError.for(
      url: URI("https://api.stagehand.browserbase.com"), status: status,
      headers: nil, body: nil, request: nil, response: nil
    )
  end
end
