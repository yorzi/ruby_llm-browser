# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::Rails::Reaper do
  let(:backend) { RubyLLM::Browser::FakeBackend.new(reconcile_state: :closed) }
  let(:logger) { Logger.new(IO::NULL) }
  let(:budget) { RubyLLM::Browser::Budget.new(max_seconds: 60, max_concurrent: 10) }
  let(:now) { fixed_time }
  let(:old) { fixed_time - 300 }

  def reaper(backend: self.backend, ttl_seconds: nil)
    described_class.new(backend: backend, store: rails_store, ttl_seconds: ttl_seconds, logger: logger)
  end

  def reserve!(state:, session_id: nil, created_at: old, id: "op-1", budget: self.budget)
    operation = build_operation(id: id, state: state, session_id: session_id,
                                budget: budget, now: created_at)
    rails_store.reserve(operation)
    operation
  end

  it "closes a reserved operation that never reached the provider" do
    operation = reserve!(state: :reserved)

    summary = reaper.sweep(now: now)

    expect(summary[:closed]).to eq(1)
    expect(rails_store.fetch(operation.id).state).to eq(:closed)
  end

  it "closes an active session the provider already reports closed" do
    operation = reserve!(state: :active, session_id: "s1")

    summary = reaper.sweep(now: now)

    expect(summary[:closed]).to eq(1)
    expect(rails_store.fetch(operation.id).state).to eq(:closed)
  end

  it "attempts a real close for a still-active session" do
    active = RubyLLM::Browser::FakeBackend.new(reconcile_state: :active)
    operation = reserve!(state: :active, session_id: "s1")

    summary = reaper(backend: active).sweep(now: now)

    expect(summary[:closed]).to eq(1)
    expect(active.call_count(:end_session)).to eq(1)
    expect(rails_store.fetch(operation.id).state).to eq(:closed)
  end

  it "keeps cleanup_pending visible when closure is unconfirmed" do
    sticky = RubyLLM::Browser::FakeBackend.new(reconcile_state: :active, end_confirmed: false)
    operation = reserve!(state: :active, session_id: "s1")

    summary = reaper(backend: sticky).sweep(now: now)

    expect(summary[:cleanup_pending]).to eq(1)
    expect(rails_store.fetch(operation.id).state).to eq(:cleanup_pending)
    expect(rails_store.fetch(operation.id)).to be_open
  end

  it "leaves an unconfirmed outcome unknown with its reservation held" do
    unknown = RubyLLM::Browser::FakeBackend.new(reconcile_state: :unknown)
    operation = reserve!(state: :unknown, session_id: "s1")

    summary = reaper(backend: unknown).sweep(now: now)

    expect(summary[:unknown]).to eq(1)
    expect(rails_store.fetch(operation.id).state).to eq(:unknown)
    expect(rails_store.fetch(operation.id)).to be_open
  end

  it "leaves a live, non-expired operation untouched" do
    operation = reserve!(state: :reserved, created_at: fixed_time)

    summary = reaper.sweep(now: now)

    expect(summary[:kept]).to eq(1)
    expect(rails_store.fetch(operation.id).state).to eq(:reserved)
  end

  it "fences a surviving worker when it closes an operation" do
    operation = reserve!(state: :reserved)

    reaper.sweep(now: now)

    expect(rails_store.fetch(operation.id).fence).to be > operation.fence
  end

  it "sweeps an idle operation by TTL even when it is within budget" do
    generous = RubyLLM::Browser::Budget.new(max_seconds: 3600, max_concurrent: 10)
    operation = reserve!(state: :active, session_id: "s1", created_at: fixed_time, budget: generous)

    summary = reaper(ttl_seconds: 30).sweep(now: fixed_time + 60)

    expect(summary[:closed]).to eq(1)
    expect(rails_store.fetch(operation.id).state).to eq(:closed)
  end
end
