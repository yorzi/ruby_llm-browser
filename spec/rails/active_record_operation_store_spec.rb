# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::Rails::ActiveRecordOperationStore do
  subject(:store) { described_class.new }

  describe "#reserve" do
    it "persists an operation that fetch returns unchanged" do
      operation = build_operation(id: "op-1", idempotency_key: "job-1")

      store.reserve(operation)

      expect(store.fetch("op-1")).to eq(operation)
    end

    it "rejects a duplicate operation id" do
      store.reserve(build_operation(id: "op-1"))

      expect { store.reserve(build_operation(id: "op-1")) }
        .to raise_error(RubyLLM::Browser::InvalidInput, /already reserved/)
      expect(store.open_operations.size).to eq(1)
    end

    it "enforces the actor concurrency budget" do
      store.reserve(build_operation(id: "op-1"))

      expect { store.reserve(build_operation(id: "op-2")) }
        .to raise_error(RubyLLM::Browser::BudgetExhausted, /open browser operation/)
      expect(store.open_operations.size).to eq(1)
    end

    it "round-trips a non-default budget" do
      budget = RubyLLM::Browser::Budget.new(max_seconds: 5, max_steps: 3, max_bytes: 1024, max_concurrent: 2)
      store.reserve(build_operation(id: "op-1", budget: budget))

      expect(store.fetch("op-1").budget).to eq(budget)
    end
  end

  describe "#attach_or_reserve" do
    it "attaches a duplicate delivery to the stored operation" do
      first = store.attach_or_reserve(build_operation(id: "op-1", idempotency_key: "job-1"))
      second = store.attach_or_reserve(build_operation(id: "op-2", idempotency_key: "job-1"))

      expect(second.id).to eq(first.id)
      expect(store.open_operations.size).to eq(1)
    end

    it "reserves a fresh operation for a new key" do
      budget = RubyLLM::Browser::Budget.new(max_concurrent: 2)
      store.attach_or_reserve(build_operation(id: "op-1", idempotency_key: "job-1", budget: budget))
      store.attach_or_reserve(build_operation(id: "op-2", idempotency_key: "job-2", budget: budget))

      expect(store.open_operations.map(&:id)).to contain_exactly("op-1", "op-2")
    end
  end

  describe "#lease" do
    before { store.reserve(build_operation(id: "op-1")) }

    it "bumps the fence and keeps the state" do
      leased = store.lease("op-1", actor_id: "actor-1", run_id: "run-1", now: fixed_time)

      expect(leased.fence).to eq(1)
      expect(leased.state).to eq(:reserved)
      expect(store.fetch("op-1").fence).to eq(1)
    end

    it "refuses a different actor or run" do
      expect { store.lease("op-1", actor_id: "other", run_id: "run-1", now: fixed_time) }
        .to raise_error(RubyLLM::Browser::NotAuthorized, /different actor/)
      expect { store.lease("op-1", actor_id: "actor-1", run_id: "other", now: fixed_time) }
        .to raise_error(RubyLLM::Browser::NotAuthorized, /different actor/)
    end

    it "refuses a terminal operation" do
      store.cancel("op-1", actor_id: "actor-1", run_id: "run-1", now: fixed_time)

      expect { store.lease("op-1", actor_id: "actor-1", run_id: "run-1", now: fixed_time) }
        .to raise_error(RubyLLM::Browser::InvalidInput, /already cancelled/)
    end
  end

  describe "#update" do
    before { store.reserve(build_operation(id: "op-1")) }

    it "persists a forward transition" do
      leased = store.lease("op-1", actor_id: "actor-1", run_id: "run-1", now: fixed_time)
      store.update(leased.advance(:starting, now: fixed_time))

      expect(store.fetch("op-1").state).to eq(:starting)
    end

    it "refuses a writer that lost the lease to a newer worker" do
      first = store.lease("op-1", actor_id: "actor-1", run_id: "run-1", now: fixed_time)
      store.lease("op-1", actor_id: "actor-1", run_id: "run-1", now: fixed_time)

      expect { store.update(first.advance(:starting, now: fixed_time)) }
        .to raise_error(RubyLLM::Browser::InvalidInput, /stale operation writer/)
      expect(store.fetch("op-1").state).to eq(:reserved)
    end
  end

  describe "#cancel" do
    before { store.reserve(build_operation(id: "op-1")) }

    it "marks the operation cancelled and fences stale workers" do
      leased = store.lease("op-1", actor_id: "actor-1", run_id: "run-1", now: fixed_time)
      cancelled = store.cancel("op-1", actor_id: "actor-1", run_id: "run-1", now: fixed_time)

      expect(cancelled.state).to eq(:cancelled)
      expect(cancelled.fence).to be > leased.fence
      expect(store.fetch("op-1")).to be_terminal
      expect(store.open_operations).to be_empty
    end

    it "refuses a different actor" do
      expect { store.cancel("op-1", actor_id: "other", run_id: "run-1", now: fixed_time) }
        .to raise_error(RubyLLM::Browser::NotAuthorized)
      expect(store.fetch("op-1").state).to eq(:reserved)
    end

    it "is idempotent for an already cancelled operation" do
      first = store.cancel("op-1", actor_id: "actor-1", run_id: "run-1", now: fixed_time)
      second = store.cancel("op-1", actor_id: "actor-1", run_id: "run-1", now: fixed_time)

      expect(second.fence).to eq(first.fence)
    end
  end

  describe "#mark_cleanup_pending and #open_for" do
    it "keeps an unresolved operation visible for the actor" do
      store.reserve(build_operation(id: "op-1"))
      store.mark_cleanup_pending("op-1", actor_id: "actor-1", run_id: "run-1", now: fixed_time)

      expect(store.fetch("op-1").state).to eq(:cleanup_pending)
      expect(store.open_for("actor-1").map(&:id)).to eq([ "op-1" ])
      expect(store.open_for("someone-else")).to be_empty
    end
  end
end
