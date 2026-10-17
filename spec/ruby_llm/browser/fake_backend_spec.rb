# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::FakeBackend do
  subject(:backend) { described_class.new }

  let(:now) { Time.utc(2026, 10, 17, 12, 0, 0) }
  let(:context) { instance_double(RubyLLM::Browser::Context, actor_id: "actor-1", run_id: "run-1") }
  let(:operation) { instance_double(RubyLLM::Browser::Operation, id: "op-1") }

  it "claims enforced egress isolation and Act support" do
    expect(backend.capabilities).to be_a(RubyLLM::Browser::Capabilities)
    expect(backend.capabilities.enforced_egress?).to be(true)
    expect(backend.capabilities.act_supported?).to be(true)
  end

  describe "#start" do
    it "returns an isolated session and records the call" do
      session = backend.start(context: context, operation: operation, now: now)
      expect(session).to be_a(RubyLLM::Browser::Session)
      expect(session.id).to eq("fake-session-1")
      expect(backend.called?(:start)).to be(true)
    end

    it "issues distinct session ids on repeated starts" do
      first = backend.start(context: context, operation: operation, now: now)
      second = backend.start(context: context, operation: operation, now: now)
      expect(second.id).not_to eq(first.id)
    end

    it "raises the configured start error" do
      failing = described_class.new(start_error: RubyLLM::Browser::SessionUnknown.new("boom"))
      expect { failing.start(context: context, operation: operation, now: now) }
        .to raise_error(RubyLLM::Browser::SessionUnknown)
    end
  end

  describe "#navigate" do
    let(:session) { RubyLLM::Browser::Session.new(id: "sess-1") }

    it "returns a session moved to the requested URL" do
      moved = backend.navigate(session, url: "https://docs.example.com/a",
                               operation: operation, now: now)
      expect(moved.url).to eq("https://docs.example.com/a")
      expect(backend.calls.last).to include(method: :navigate, url: "https://docs.example.com/a")
    end

    it "can simulate an in-provider redirect" do
      redirecting = described_class.new(redirect_to: "https://evil.test/")
      moved = redirecting.navigate(session, url: "https://docs.example.com/a",
                                   operation: operation, now: now)
      expect(moved.url).to eq("https://evil.test/")
    end
  end

  describe "scripted results" do
    let(:session) { RubyLLM::Browser::Session.new(id: "sess-1") }

    it "returns observations, extraction and action results by default" do
      expect(backend.observe(session, instruction: nil, operation: operation, now: now))
        .to eq(described_class::DEFAULT_OBSERVE)
      expect(backend.extract(session, schema: {}, instruction: nil, operation: operation, now: now))
        .to eq(described_class::DEFAULT_EXTRACT)
      expect(backend.act(session, action: {}, operation: operation, now: now))
        .to eq(described_class::DEFAULT_ACT)
    end

    it "hands back a deep copy so callers cannot mutate the script" do
      observed = backend.observe(session, instruction: nil, operation: operation, now: now)
      observed.first["description"] = "tampered"
      expect(backend.observe(session, instruction: nil, operation: operation, now: now))
        .to eq(described_class::DEFAULT_OBSERVE)
    end

    it "raises configured per-method errors" do
      failing = described_class.new(act_error: RubyLLM::Browser::ProviderError.new("nope"))
      expect { failing.act(session, action: {}, operation: operation, now: now) }
        .to raise_error(RubyLLM::Browser::ProviderError)
    end
  end

  describe "#end_session" do
    let(:session) { RubyLLM::Browser::Session.new(id: "sess-1") }

    it "confirms closure by default" do
      expect(backend.end_session(session, operation: operation, now: now)).to be(true)
    end

    it "can report unconfirmed closure" do
      unconfirmed = described_class.new(end_confirmed: false)
      expect(unconfirmed.end_session(session, operation: operation, now: now)).to be(false)
    end
  end

  it "counts and detects recorded calls" do
    backend.start(context: context, operation: operation, now: now)
    expect(backend.call_count(:start)).to eq(1)
    expect(backend.call_count(:navigate)).to eq(0)
  end
end
