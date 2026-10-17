# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::InMemoryOperationStore do
  let(:now) { Time.utc(2026, 10, 17, 12, 0, 0) }

  def operation(id:, budget: RubyLLM::Browser::Budget.new(max_concurrent: 1), actor: "actor-1", run: "run-1",
                idempotency_key: nil)
    RubyLLM::Browser::Operation.new(id: id, actor_id: actor, run_id: run, budget: budget,
                                    idempotency_key: idempotency_key, created_at: now, updated_at: now)
  end

  it "reserves and fetches an operation" do
    store = described_class.new
    store.reserve(operation(id: "op-1"))
    expect(store.fetch("op-1").id).to eq("op-1")
    expect(store.fetch("missing")).to be_nil
    expect { store.fetch!("missing") }.to raise_error(RubyLLM::Browser::InvalidInput)
  end

  it "refuses a duplicate id" do
    store = described_class.new
    store.reserve(operation(id: "op-1"))
    expect { store.reserve(operation(id: "op-1")) }
      .to raise_error(RubyLLM::Browser::InvalidInput, /already reserved/)
  end

  it "enforces the actor concurrency budget and frees the slot on closure" do
    store = described_class.new
    first = operation(id: "op-1")
    store.reserve(first)
    expect { store.reserve(operation(id: "op-2")) }
      .to raise_error(RubyLLM::Browser::BudgetExhausted, /open browser operation/)

    closed = first.advance(:closed, now: now)
    store.update(closed)
    expect { store.reserve(operation(id: "op-3")) }.not_to raise_error
    expect(store.open_for("actor-1").map(&:id)).to eq([ "op-3" ])
  end

  it "attaches a duplicate job to the existing operation" do
    store = described_class.new
    first = store.attach_or_reserve(operation(id: "op-1", idempotency_key: "job-1"))
    again = store.attach_or_reserve(operation(id: "op-2", idempotency_key: "job-1"))
    expect(again.id).to eq(first.id)

    other_actor = store.attach_or_reserve(operation(id: "op-3", idempotency_key: "job-1", actor: "actor-2",
                                                   budget: RubyLLM::Browser::Budget.new(max_concurrent: 5)))
    expect(other_actor.id).to eq("op-3")
  end

  it "bumps the fence on lease and rejects a different actor" do
    store = described_class.new
    store.reserve(operation(id: "op-1", budget: RubyLLM::Browser::Budget.new(max_concurrent: 2)))
    leased = store.lease("op-1", actor_id: "actor-1", run_id: "run-1", now: now)
    expect(leased.fence).to eq(1)

    expect { store.lease("op-1", actor_id: "actor-2", run_id: "run-1", now: now) }
      .to raise_error(RubyLLM::Browser::NotAuthorized)
  end

  it "refuses to lease a terminal operation" do
    store = described_class.new
    store.reserve(operation(id: "op-1").advance(:closed, now: now))
    expect { store.lease("op-1", actor_id: "actor-1", run_id: "run-1", now: now) }
      .to raise_error(RubyLLM::Browser::InvalidInput, /already closed/)
  end

  it "rejects a stale writer" do
    store = described_class.new
    store.reserve(operation(id: "op-1", budget: RubyLLM::Browser::Budget.new(max_concurrent: 2)))
    leased = store.lease("op-1", actor_id: "actor-1", run_id: "run-1", now: now)
    store.lease("op-1", actor_id: "actor-1", run_id: "run-1", now: now)

    stale = leased.advance(:starting, now: now)
    expect { store.update(stale) }
      .to raise_error(RubyLLM::Browser::InvalidInput, /stale operation writer/)
  end

  it "marks cleanup pending" do
    store = described_class.new
    store.reserve(operation(id: "op-1"))
    updated = store.mark_cleanup_pending("op-1", actor_id: "actor-1", run_id: "run-1",
                                         error_code: "PROVIDER_ERROR", now: now)
    expect(updated.state).to eq(:cleanup_pending)
    expect(updated.error_code).to eq("PROVIDER_ERROR")
  end
end
