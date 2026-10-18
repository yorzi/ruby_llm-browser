# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::Rails::OperationJob do
  let(:backend) { RubyLLM::Browser::FakeBackend.new }
  let(:policy) { build_policy }
  let(:budget) { RubyLLM::Browser::Budget.new(max_concurrent: 5) }
  let(:url) { "https://docs.example.com/a" }
  let(:operation) do
    build_operation(id: "op-1", idempotency_key: "job-1", budget: budget)
  end

  def install_factory(backend: self.backend, policy: self.policy, budget: self.budget, &on_build)
    described_class.context_factory = lambda do |actor_id:, run_id:|
      on_build&.call
      RubyLLM::Browser::Context.new(
        actor_id: actor_id, run_id: run_id, backend: backend, source_policy: policy,
        operation_store: rails_store, budget: budget, clock: -> { fixed_time }
      )
    end
  end

  def perform(candidate, actor_id: candidate.actor_id, run_id: candidate.run_id,
              kind: "inspect", **overrides)
    described_class.perform_now(
      operation_id: candidate.id, actor_id: actor_id, run_id: run_id,
      kind: kind, url: url, **overrides
    )
  end

  def reserve!(candidate)
    rails_store.reserve(candidate)
    candidate
  end

  describe ".enqueue" do
    it "rejects a different payload using the same actor/run idempotency key" do
      described_class.enqueue(actor_id: "actor-1", run_id: "run-1", kind: :inspect,
                             url: url, budget: budget, idempotency_key: "job-1")

      expect do
        described_class.enqueue(actor_id: "actor-1", run_id: "run-1", kind: :inspect,
                               url: "https://docs.example.com/other", budget: budget, idempotency_key: "job-1")
      end.to raise_error(RubyLLM::Browser::InvalidInput, /different request/)
    end

    it "reserves one durable operation and schedules one job" do
      stored = described_class.enqueue(
        actor_id: "actor-1", run_id: "run-1", kind: :inspect, url: url,
        budget: budget, idempotency_key: "job-1"
      )

      expect(stored.state).to eq(:reserved)
      expect(rails_store.fetch(stored.id)).to eq(stored)
      expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq(1)
    end

    it "attaches a duplicate delivery to the same operation" do
      first = described_class.enqueue(
        actor_id: "actor-1", run_id: "run-1", kind: :inspect, url: url,
        budget: budget, idempotency_key: "job-1"
      )
      second = described_class.enqueue(
        actor_id: "actor-1", run_id: "run-1", kind: :inspect, url: url,
        budget: budget, idempotency_key: "job-1"
      )

      expect(second.id).to eq(first.id)
      expect(rails_store.open_operations.size).to eq(1)
      expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq(2)
    end
  end

  describe "#perform" do
    it "runs the operation and records a confirmed closure" do
      reserve!(operation)
      install_factory

      result = perform(operation)

      expect(result[:status]).to eq("truncated").or eq("ok")
      expect(result[:final_url]).to eq(url)
      expect(rails_store.fetch(operation.id).state).to eq(:closed)
      expect(backend.call_count(:observe)).to eq(1)
    end

    it "runs an extraction against the host schema" do
      reserve!(operation)
      install_factory
      schema = { "type" => "object", "properties" => { "title" => { "type" => "string" } } }

      result = perform(operation, kind: "extract", schema: schema)

      expect(result[:locator]["scope"]).to eq("extract")
      expect(rails_store.fetch(operation.id).state).to eq(:closed)
    end

    it "returns :missing for an unknown operation" do
      expect(perform(build_operation(id: "op-missing"))).to eq(:missing)
    end

    it "returns :terminal for an already closed operation" do
      reserve!(build_operation(id: "op-closed", state: :closed))

      expect(perform(build_operation(id: "op-closed"))).to eq(:terminal)
      expect(backend.call_count(:start)).to eq(0)
    end

    it "returns :attached for a non-reserved operation" do
      reserve!(build_operation(id: "op-active", state: :active, session_id: "s1"))

      expect(perform(build_operation(id: "op-active"))).to eq(:attached)
      expect(backend.call_count(:start)).to eq(0)
    end

    it "raises for a different actor and starts no session" do
      reserve!(operation)
      install_factory

      expect { perform(operation, actor_id: "someone-else") }
        .to raise_error(RubyLLM::Browser::NotAuthorized)
      expect(backend.call_count(:start)).to eq(0)
      expect(rails_store.fetch(operation.id).state).to eq(:reserved)
    end

    it "aborts as fenced_out when a newer worker takes the lease" do
      reserve!(operation)
      install_factory do
        rails_store.lease(operation.id, actor_id: operation.actor_id, run_id: operation.run_id,
                                        now: fixed_time)
      end

      expect(perform(operation)).to eq(:fenced_out)
      expect(backend.call_count(:start)).to eq(0)
      expect(rails_store.fetch(operation.id).state).to eq(:reserved)
    end

    it "reports :cancelled and still cleans up when the host cancels mid-session" do
      reserve!(operation)
      cancel = lambda do |live|
        rails_store.cancel(live.id, actor_id: live.actor_id, run_id: live.run_id, now: fixed_time)
      end
      cancelling = BrowserSpecSupport::CancellingBackend.new(on_observe: cancel)
      install_factory(backend: cancelling)

      expect(perform(operation)).to eq(:cancelled)
      expect(rails_store.fetch(operation.id).state).to eq(:cancelled)
      expect(cancelling.call_count(:end_session)).to eq(1)
    end
  end
end
