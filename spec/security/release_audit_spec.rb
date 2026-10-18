# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::Engine do
  let(:url) { "https://docs.example.com/a" }
  let(:schema) do
    { "type" => "object", "properties" => { "title" => { "type" => "string" } },
      "required" => [ "title" ], "additionalProperties" => false }
  end

  it "does not let a model increase the host output ceiling" do
    backend = RubyLLM::Browser::FakeBackend.new(observe: { "text" => "x" * 1000 })
    context = build_context(backend: backend, policy: build_policy(max_result_bytes: 64))
    result = described_class.new(context: context).inspect(url: url, max_bytes: 10_000)

    expect(result).to be_truncated
    expect(JSON.generate(result.data).bytesize).to be <= 64
  end

  it "bounds actual serialized UTF-8 and escaped JSON, including very small limits" do
    [ 1, 2, 8, 32, 64, 100 ].each do |limit|
      bounded, truncated = RubyLLM::Browser::Redactor.bound({ "text" => "\"\\中" * 1000 }, max_bytes: limit)
      expect(truncated).to be(true)
      expect(JSON.generate(bounded).bytesize).to be <= limit
    end
  end

  it "enforces the operation byte budget and keeps the accounted bytes" do
    backend = RubyLLM::Browser::FakeBackend.new(observe: { "text" => "x" * 1000 })
    store = RubyLLM::Browser::InMemoryOperationStore.new
    context = build_context(backend: backend, operation_store: store,
                            budget: RubyLLM::Browser::Budget.new(max_bytes: 64))
    result = described_class.new(context: context).inspect(url: url)

    expect(result).to be_truncated
    expect(store.fetch(result.operation_id).bytes).to eq(JSON.generate(result.data).bytesize)
    expect(store.fetch(result.operation_id).bytes).to be <= 64
  end

  it "refuses provider data that does not match the extraction schema" do
    backend = RubyLLM::Browser::FakeBackend.new(extract: { "title" => 42 })
    result = described_class.new(context: build_context(backend: backend)).extract(url: url, schema: schema)

    expect(result.status).to eq(:error)
    expect(result.error_code).to eq("PROVIDER_ERROR")
    expect(result.data).to be_nil
    expect(backend.call_count(:end_session)).to eq(1)
  end

  it "refuses malformed schema shapes with a typed error before starting" do
    backend = RubyLLM::Browser::FakeBackend.new
    engine = described_class.new(context: build_context(backend: backend))

    expect { engine.extract(url: url, schema: { "type" => "object", "properties" => [] }) }
      .to raise_error(RubyLLM::Browser::InvalidInput)
    expect(backend.call_count(:start)).to eq(0)
  end

  it "does not start an already expired caller operation" do
    store = RubyLLM::Browser::InMemoryOperationStore.new
    backend = RubyLLM::Browser::FakeBackend.new
    context = build_context(backend: backend, operation_store: store)
    operation = store.reserve(build_operation(now: fixed_time - 300))

    expect { described_class.new(context: context).inspect(url: url, operation: operation) }
      .to raise_error(RubyLLM::Browser::BudgetExhausted)
    expect(backend.call_count(:start)).to eq(0)
  end

  it "cannot restart an already-started operation from a stale reserved copy" do
    store = RubyLLM::Browser::InMemoryOperationStore.new
    backend = RubyLLM::Browser::FakeBackend.new
    context = build_context(backend: backend, operation_store: store)
    original = store.reserve(build_operation)
    store.update(original.advance(:starting, now: fixed_time))

    expect { described_class.new(context: context).inspect(url: url, operation: original) }
      .to raise_error(RubyLLM::Browser::InvalidInput)
    expect(backend.call_count(:start)).to eq(0)
  end

  it "holds quota and exposes cancellation until remote cleanup is confirmed" do
    operation = rails_store.reserve(build_operation(state: :active, session_id: "live-session"))
    cancelled = rails_store.cancel(operation.id, actor_id: operation.actor_id,
                                  run_id: operation.run_id, now: fixed_time)

    expect(cancelled.state).to eq(:cleanup_pending)
    expect(cancelled).to be_open
    expect { rails_store.reserve(build_operation) }.to raise_error(RubyLLM::Browser::BudgetExhausted)
  end

  it "rejects policy mutation through the original allowlist" do
    hosts = [ +"docs.example.com" ]
    policy = build_policy(allowed_hosts: hosts)
    hosts.first.replace("evil.example.com")

    expect(policy.allowed_hosts).to eq([ "docs.example.com" ])
    expect { policy.allowed_hosts << "evil.example.com" }.to raise_error(FrozenError)
  end

  it "still closes a session if persisting its returned identity fails" do
    backend = RubyLLM::Browser::FakeBackend.new
    context = build_context(backend: backend)
    allow(context.operation_store).to receive(:record_session).and_raise(StandardError, "private database details")

    result = described_class.new(context: context).inspect(url: url)

    expect(backend.call_count(:end_session)).to eq(1)
    expect(result.status).to eq(:cleanup_pending)
    expect(result.to_json).not_to include("private database details")
  end

  it "persists a session returned after cancellation and holds quota if cleanup fails" do
    backend = RubyLLM::Browser::FakeBackend.new(end_confirmed: false)
    context = build_context(backend: backend, operation_store: rails_store)
    allow(backend).to receive(:start).and_wrap_original do |original, **arguments|
      operation = arguments.fetch(:operation)
      rails_store.cancel(operation.id, actor_id: operation.actor_id, run_id: operation.run_id, now: fixed_time)
      original.call(**arguments)
    end

    result = described_class.new(context: context).inspect(url: url)
    stored = rails_store.fetch(result.operation_id)

    expect(result.status).to eq(:cleanup_pending)
    expect(stored.session_id).to eq("fake-session-1")
    expect(stored).to be_open
    expect(stored).to be_cancel_requested
    expect(backend.call_count(:navigate)).to eq(0)
  end

  it "records an unknown action outcome even when cleanup confirms session closure" do
    backend = RubyLLM::Browser::FakeBackend.new(act_error: RubyLLM::Browser::SessionUnknown.new("uncertain"))
    approvals = RubyLLM::Browser::InMemoryApprovalStore.new
    context = build_context(backend: backend, approval_store: approvals)
    action = context.policy.authorize_action!("method" => "click", "selector" => "a#docs")
    grant = build_approval(approvals, context: context, url: url, action: action)

    result = described_class.new(context: context).act(url: url, approval_id: grant.id, action: action)

    expect(result.status).to eq(:unknown)
    expect(context.operation_store.fetch(result.operation_id).error_code).to eq("SESSION_UNKNOWN")
    expect(approvals.fetch(grant.id)).to be_consumed
  end

  it "redacts query credentials from both provenance URL fields" do
    result = described_class.new(context: build_context).inspect(url: "#{url}?access_token=private-value")

    expect(result.to_json).not_to include("private-value")
    expect(result.locator["url"]).to eq(result.final_url)
  end

  it "refuses live Act before start even when a backend advertises action support" do
    backend = RubyLLM::Browser::FakeBackend.new(capabilities: RubyLLM::Browser::Capabilities.new(
      server_mode: :remote, egress_isolation: :enforced, act_supported: true
    ))
    context = build_context(backend: backend, approval_store: RubyLLM::Browser::InMemoryApprovalStore.new)

    expect { described_class.new(context: context).act(url: url, approval_id: "host-grant", action: {}) }
      .to raise_error(RubyLLM::Browser::UnsupportedSecurityCapability, /same-session/)
    expect(backend.call_count(:start)).to eq(0)
  end

  it "supports direct tools with durable storage and a real fractional-second clock" do
    context = build_context(operation_store: rails_store, clock: -> { Time.now.utc })

    result = described_class.new(context: context).inspect(url: url)

    expect(result).to be_ok
    expect(rails_store.fetch(result.operation_id).state).to eq(:closed)
  end

  it "does not resolve known-vulnerable Ruby default gems on clean installation" do
    root = File.expand_path("../..", __dir__)
    specification = Gem::Specification.load(File.join(root, "ruby_llm-browser.gemspec"))
    dependencies = specification.runtime_dependencies.to_h { |dependency| [ dependency.name, dependency.requirement ] }
    { "cgi" => "0.4.1", "resolv" => "0.3.0", "uri" => "0.13.1", "zlib" => "3.1.1" }.each do |name, vulnerable|
      expect(dependencies.fetch(name).satisfied_by?(Gem::Version.new(vulnerable))).to be(false)
    end
  end

  it "honors configured budget and result defaults without changing existing contexts" do
    original = build_context
    budget = RubyLLM::Browser::Budget.new(max_steps: 3)
    RubyLLM::Browser.configure do |configuration|
      configuration.default_budget = budget
      configuration.max_result_bytes = 128
    end

    expect(build_context.budget).to eq(budget)
    expect(build_policy.max_result_bytes).to eq(128)
    expect(original.budget.max_steps).to eq(12)
  ensure
    RubyLLM::Browser.reset_configuration!
  end

  it "does not expose unexpected database failure details through a tool" do
    context = build_context
    allow(context.operation_store).to receive(:reserve).and_raise(StandardError, "private database credentials")

    result = RubyLLM::Browser::Inspect.new(context: context).execute(url: url)

    expect(result[:error][:code]).to eq("PROVIDER_ERROR")
    expect(result.to_s).not_to include("private database credentials")
    expect(context.backend.call_count(:start)).to eq(0)
  end
end
