# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::Context do
  subject(:context) { build_context }

  it "requires an actor and a run" do
    expect { build_context(actor_id: "") }
      .to raise_error(RubyLLM::Browser::InvalidInput, /actor_id/)
    expect { build_context(run_id: "") }
      .to raise_error(RubyLLM::Browser::InvalidInput, /run_id/)
  end

  it "requires a real backend" do
    expect do
      described_class.new(actor_id: "a", run_id: "r", backend: :nope, source_policy: build_policy,
                          operation_store: RubyLLM::Browser::InMemoryOperationStore.new)
    end.to raise_error(RubyLLM::Browser::InvalidInput, /backend/)
  end

  it "requires a Policy, an OperationStore and an ApprovalStore" do
    store = RubyLLM::Browser::InMemoryOperationStore.new
    expect do
      described_class.new(actor_id: "a", run_id: "r", backend: RubyLLM::Browser::FakeBackend.new,
                          source_policy: :nope, operation_store: store)
    end.to raise_error(RubyLLM::Browser::InvalidInput, /source_policy/)
    expect do
      described_class.new(actor_id: "a", run_id: "r", backend: RubyLLM::Browser::FakeBackend.new,
                          source_policy: build_policy, operation_store: :nope)
    end.to raise_error(RubyLLM::Browser::InvalidInput, /operation_store/)
    expect do
      described_class.new(actor_id: "a", run_id: "r", backend: RubyLLM::Browser::FakeBackend.new,
                          source_policy: build_policy, operation_store: store, approval_store: :nope)
    end.to raise_error(RubyLLM::Browser::InvalidInput, /approval_store/)
  end

  it "defaults the budget, clock and logger" do
    expect(context.budget).to be_a(RubyLLM::Browser::Budget)
    expect(context.now).to eq(fixed_time)
    expect(context.logger).to be_a(Logger)
  end

  it "carries the backend capabilities and policy" do
    expect(context.capabilities).to eq(context.backend.capabilities)
    expect(context.policy).to eq(context.source_policy)
  end

  it "collects the backend's secret literals" do
    backend = RubyLLM::Browser::FakeBackend.new
    def backend.secrets = [ "sk-secret-value" ]
    expect(build_context(backend: backend).secrets).to eq([ "sk-secret-value" ])
  end

  it "summarizes without backend credentials" do
    summary = context.to_h
    expect(summary).to include(actor_id: "actor-1", run_id: "run-1", consent: false)
    expect(summary[:capabilities]).to eq(context.capabilities.to_h)
    expect(context.inspect).to include("actor=actor-1")
  end

  it "records that consent was granted without leaking the record" do
    expect(build_context(consent: Object.new).to_h[:consent]).to be(true)
  end

  it "is frozen" do
    expect(context).to be_frozen
  end
end
