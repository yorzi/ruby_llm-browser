# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::Operation do
  subject(:operation) do
    described_class.new(id: "op-1", actor_id: "actor-1", run_id: "run-1", budget: budget, created_at: now,
                        updated_at: now)
  end

  let(:now) { Time.utc(2026, 10, 17, 12, 0, 0) }
  let(:budget) { RubyLLM::Browser::Budget.new(max_seconds: 60, max_steps: 2, max_bytes: 8) }


  it "starts reserved and open" do
    expect(operation.state).to eq(:reserved)
    expect(operation).to be_open
    expect(operation).not_to be_terminal
  end

  it "generates unique ids" do
    expect(described_class.generate_id(prefix: "op")).to start_with("op_")
    expect(described_class.generate_id).not_to eq(described_class.generate_id)
  end

  describe "transitions" do
    it "allows the documented lifecycle" do
      started = operation.advance(:starting, now: now)
      active = started.advance(:active, now: now, session_id: "sess-1")
      closing = active.advance(:closing, now: now)
      closed = closing.advance(:closed, now: now)

      expect(active.session_id).to eq("sess-1")
      expect(closed).to be_terminal
      expect(closed.state).to eq(:closed)
    end

    it "allows an ambiguous outcome to become unknown or cleanup_pending" do
      starting = operation.advance(:starting, now: now)
      expect(starting.advance(:unknown, now: now).state).to eq(:unknown)
      expect(starting.advance(:cleanup_pending, now: now).state).to eq(:cleanup_pending)
    end

    it "refuses illegal transitions" do
      expect { operation.advance(:active, now: now) }
        .to raise_error(RubyLLM::Browser::InvalidInput, /illegal operation transition/)

      closed = operation.advance(:starting, now: now).advance(:active, now: now).advance(:closing, now: now)
        .advance(:closed, now: now)
      expect { closed.advance(:active, now: now) }
        .to raise_error(RubyLLM::Browser::InvalidInput, /illegal operation transition/)
    end

    it "allows advancing to the same state to refresh" do
      expect(operation.advance(:reserved, now: now + 5).updated_at).to eq(now + 5)
    end
  end

  describe "budgets" do
    it "counts steps and refuses to exceed them" do
      once = operation.consume_step!(now: now)
      twice = once.consume_step!(now: now)
      expect(twice.steps).to eq(2)
      expect(twice.steps_exhausted?).to be(true)
      expect { twice.consume_step!(now: now) }
        .to raise_error(RubyLLM::Browser::BudgetExhausted)
    end

    it "tracks bytes and remaining capacity" do
      updated = operation.add_bytes!(3, now: now)
      expect(updated.bytes).to eq(3)
      expect(updated.remaining_bytes).to eq(5)
      expect(updated.bytes_exhausted?).to be(false)
      expect(updated.add_bytes!(5, now: now)).to be_bytes_exhausted
      expect { updated.add_bytes!(-1, now: now) }.to raise_error(RubyLLM::Browser::InvalidInput)
    end

    it "reports elapsed and expired time" do
      expect(operation.elapsed_seconds(now + 30)).to eq(30.0)
      expect(operation.expired?(now + 30)).to be(false)
      expect(operation.expired?(now + 61)).to be(true)
    end
  end

  it "bumps the fence without changing state" do
    fenced = operation.with_fence(3, now: now)
    expect(fenced.fence).to eq(3)
    expect(fenced.state).to eq(:reserved)
  end

  it "summarizes without the provider session id" do
    active = operation.advance(:starting, now: now).advance(:active, now: now, session_id: "sess-secret")
    expect(active.summary).not_to have_key(:session_id)
    expect(active.to_h[:session_id]).to eq("sess-secret")
  end

  it "validates its inputs" do
    expect { described_class.new(id: "", actor_id: "a", run_id: "r", budget: budget) }
      .to raise_error(RubyLLM::Browser::InvalidInput, /id/)
    expect { described_class.new(id: "op", actor_id: "a", run_id: "r", budget: :nope) }
      .to raise_error(RubyLLM::Browser::InvalidInput, /budget/)
    expect { described_class.new(id: "op", actor_id: "a", run_id: "r", budget: budget, state: :bogus) }
      .to raise_error(RubyLLM::Browser::InvalidInput, /state/)
  end

  it "compares by value" do
    expect(operation.same_identity?(operation)).to be(true)
  end
end
