# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::Rails do
  let(:adapter) { described_class }
  let(:job) { adapter::OperationJob }
  let(:backend) { RubyLLM::Browser::FakeBackend.new }
  let(:deliveries) { [] }
  let(:schema) do
    { "type" => "object", "properties" => { "title" => { "type" => "string" } },
      "required" => [ "title" ], "additionalProperties" => false }
  end
  let(:arguments) do
    { actor_id: "actor-1", run_id: "run-1", kind: :extract,
      url: "https://docs.example.com/", schema: schema }
  end

  before do
    adapter.context_factory = lambda do |actor_id:, run_id:|
      build_context(actor_id: actor_id, run_id: run_id, backend: backend,
                    operation_store: rails_store)
    end
    adapter.result_delivery = ->(operation:, result:) { deliveries << [ operation, result ] }
  end

  def enqueue(**overrides)
    job.enqueue(**arguments.merge(budget: RubyLLM::Browser::Budget.new, idempotency_key: "delivery-1").merge(overrides))
  end

  def perform(operation, **overrides)
    job.perform_now(operation_id: operation.id, **arguments.merge(overrides))
  end

  it "delivers the sanitized immutable Result after closure with trusted actor/run identity" do
    operation = enqueue
    returned = perform(operation)
    stored, result = deliveries.fetch(0)

    expect(stored).to eq(rails_store.fetch(operation.id))
    expect(stored.state).to eq(:closed)
    expect([ stored.actor_id, stored.run_id ]).to eq(%w[actor-1 run-1])
    expect(result).to be_a(RubyLLM::Browser::Result)
    expect(result).to be_frozen
    expect(result.to_h).to eq(returned)
    expect(result.data).to eq("title" => "Example")
    expect(result.locator).to include("scope" => "extract", "schema_digest" => RubyLLM::Browser::Redactor.digest(schema))
    expect(result.to_json).not_to include("fake-session-1")
    expect(backend.call_count(:end_session)).to eq(1)
  end

  it "keeps delivery opt-in and preserves the existing return value" do
    adapter.result_delivery = nil
    expect(perform(enqueue)).to include(status: "ok", data: { "title" => "Example" })
    expect(deliveries).to be_empty
  end

  it "rejects invalid delivery configuration before work can be queued" do
    expect { adapter.result_delivery = Object.new }.to raise_error(RubyLLM::Browser::InvalidInput)
  end

  it "clears the delivery hook on reset" do
    adapter.reset!
    expect(adapter.result_delivery).to be_nil
  end

  it "does not repeat browser work or delivery for a duplicate job" do
    operation = enqueue
    perform(operation)
    expect(perform(enqueue)).to eq(:terminal)
    expect(deliveries.length).to eq(1)
    expect(backend.call_count(:start)).to eq(1)
  end

  it "reports a safe delivery error and permits retrying only the retained result" do
    operation = enqueue
    adapter.result_delivery = ->(**) { raise "database password=private-secret stale cancelled" }
    failure = nil
    expect { perform(operation) }.to raise_error(adapter::ResultDeliveryError) { |error| failure = error }

    expect(failure.code).to eq("RESULT_DELIVERY_FAILED")
    expect(failure.to_h.to_json).not_to include("private-secret")
    expect(failure.cause).to be_nil
    expect(failure.operation.state).to eq(:closed)
    expect(failure.result.data).to eq("title" => "Example")
    expect(rails_store.fetch(operation.id).error_code).to be_nil
    expect(perform(operation)).to eq(:terminal)
    adapter.result_delivery = ->(operation:, result:) { deliveries << [ operation, result ] }
    adapter.result_delivery.call(operation: failure.operation, result: failure.result)
    expect(deliveries.length).to eq(1)
    expect(backend.call_count(:start)).to eq(1)
    expect(backend.call_count(:end_session)).to eq(1)
  end

  it "does not hide a callback InvalidInput as a fenced worker" do
    adapter.result_delivery = ->(**) { raise RubyLLM::Browser::InvalidInput, "stale host write" }
    expect { perform(enqueue) }.to raise_error(adapter::ResultDeliveryError)
  end

  context "with bounded output" do
    let(:backend) { RubyLLM::Browser::FakeBackend.new(extract: { "title" => "x" * 100 }) }

    it "delivers truncation without promising schema validity for the bounded representation" do
      operation = enqueue(max_bytes: 30)
      returned = perform(operation, max_bytes: 30)
      expect(deliveries.fetch(0).last.status).to eq(:truncated)
      expect(returned[:truncated]).to be(true)
    end
  end

  context "with redacted output" do
    let(:backend) { RubyLLM::Browser::FakeBackend.new(extract: { "title" => "wss://secret-value/devtools/browser" }) }

    it "applies core redaction before host delivery" do
      perform(enqueue)
      expect(deliveries.fetch(0).last.to_json).not_to include("secret-value")
    end
  end

  {
    "provider rejection" => [ { start_error: RubyLLM::Browser::ProviderError.new("refused") }, :error, :closed ],
    "unknown start" => [ { start_error: IOError.new("lost response") }, :unknown, :unknown ],
    "invalid extracted data" => [ { extract: { "title" => 123 } }, :error, :closed ],
    "pending cleanup" => [ { end_confirmed: false }, :cleanup_pending, :cleanup_pending ]
  }.each do |label, (options, result_status, state)|
    context "with #{label}" do
      let(:backend) { RubyLLM::Browser::FakeBackend.new(**options) }

      it "delivers the failure without changing the session state" do
        operation = enqueue
        perform(operation)
        stored, result = deliveries.fetch(0)
        expect(result.status).to eq(result_status)
        expect(result.error_code).not_to be_nil
        expect(stored.state).to eq(state)
        expect(rails_store.fetch(operation.id).state).to eq(state)
        expect(perform(operation)).to eq(state == :closed ? :terminal : :attached)
        expect(deliveries.length).to eq(1)
        expect(backend.call_count(:start)).to eq(1)
      end

      it "keeps the same state and quota when host delivery fails" do
        adapter.result_delivery = ->(**) { raise "host storage failed" }
        operation = enqueue
        expect { perform(operation) }.to raise_error(adapter::ResultDeliveryError) do |error|
          expect(error.result.status).to eq(result_status)
          expect(error.operation.state).to eq(state)
        end
        current = rails_store.fetch(operation.id)
        expect(current.state).to eq(state)
        expect(rails_store.open_for(operation.actor_id).map(&:id)).to eq(state == :closed ? [] : [ operation.id ])
        expect(perform(operation)).to eq(state == :closed ? :terminal : :attached)
        expect(backend.call_count(:start)).to eq(1)
      end
    end
  end

  it "does not deliver a result for policy rejection before browser execution" do
    operation = enqueue(url: "https://blocked.example/")
    expect { perform(operation, url: "https://blocked.example/") }.to raise_error(RubyLLM::Browser::NotAuthorized)
    expect(deliveries).to be_empty
    expect(backend.call_count(:start)).to eq(0)
  end

  it "does not deliver after cancellation with unconfirmed cleanup" do
    cancel = ->(live) { rails_store.cancel(live.id, actor_id: live.actor_id, run_id: live.run_id, now: fixed_time) }
    cancelling = BrowserSpecSupport::CancellingBackend.new(on_observe: cancel, end_confirmed: false)
    adapter.context_factory = ->(**scope) { build_context(**scope, backend: cancelling, operation_store: rails_store) }
    operation = enqueue(kind: :inspect, schema: nil)
    expect(perform(operation, kind: :inspect, schema: nil)).to include(status: "cleanup_pending")
    expect(rails_store.fetch(operation.id)).to be_cancel_requested
    expect(deliveries).to be_empty
    expect(cancelling.call_count(:end_session)).to eq(1)
  end

  it "does not deliver after cancellation with confirmed cleanup" do
    cancel = ->(live) { rails_store.cancel(live.id, actor_id: live.actor_id, run_id: live.run_id, now: fixed_time) }
    cancelling = BrowserSpecSupport::CancellingBackend.new(on_observe: cancel)
    adapter.context_factory = ->(**scope) { build_context(**scope, backend: cancelling, operation_store: rails_store) }
    operation = enqueue(kind: :inspect, schema: nil)
    expect(perform(operation, kind: :inspect, schema: nil)).to eq(:cancelled)
    expect(deliveries).to be_empty
    expect(cancelling.call_count(:end_session)).to eq(1)
  end

  it "does not deliver or start work cancelled before execution" do
    operation = enqueue
    rails_store.cancel(operation.id, actor_id: operation.actor_id, run_id: operation.run_id, now: fixed_time)
    expect(perform(operation)).to eq(:cancelled)
    expect(deliveries).to be_empty
    expect(backend.call_count(:start)).to eq(0)
  end

  it "suppresses a result from a worker fenced during observation" do
    fence = ->(live) { rails_store.lease(live.id, actor_id: live.actor_id, run_id: live.run_id, now: fixed_time) }
    fenced = BrowserSpecSupport::CancellingBackend.new(on_observe: fence)
    adapter.context_factory = ->(**scope) { build_context(**scope, backend: fenced, operation_store: rails_store) }
    operation = enqueue(kind: :inspect, schema: nil)
    expect(perform(operation, kind: :inspect, schema: nil)).to eq(:fenced_out)
    expect(deliveries).to be_empty
    expect(fenced.call_count(:end_session)).to eq(1)
  end
end
