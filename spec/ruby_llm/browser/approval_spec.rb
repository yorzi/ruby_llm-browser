# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::Approval do
  subject(:approval) do
    described_class.for_action(actor_id: "actor-1", run_id: "run-1", url: "https://docs.example.com/a",
                               action: action, ttl: 60, now: now)
  end

  let(:now) { Time.utc(2026, 10, 17, 12, 0, 0) }
  let(:action) do
    { "description" => "click download", "method" => "click", "selector" => "a#dl", "arguments" => [] }
  end


  it "derives a stable action digest" do
    expect(approval.action_digest).to eq(described_class.action_digest(action))
    expect(approval.action_digest).to eq(described_class.action_digest(action.to_a.reverse.to_h))
  end

  it "derives a stable page revision from observed candidates" do
    observed = [ { "selector" => "a" }, { "selector" => "b" } ]
    copy = [ { "selector" => "a" }, { "selector" => "b" } ]
    expect(described_class.page_revision(observed)).to eq(described_class.page_revision(copy))
    expect(described_class.page_revision(observed))
      .not_to eq(described_class.page_revision([ { "selector" => "a" }, { "selector" => "c" } ]))
  end

  it "is active until it expires" do
    expect(approval.active?(now)).to be(true)
    expect(approval.expired?(now + 60)).to be(true)
    expect(approval.active?(now + 60)).to be(false)
  end

  it "matches only its exact binding" do
    base = { actor_id: "actor-1", run_id: "run-1", url: "https://docs.example.com/a",
             action_digest: approval.action_digest }
    expect(approval.binding_matches?(**base)).to be(true)
    expect(approval.binding_matches?(**base.merge(actor_id: "actor-2"))).to be(false)
    expect(approval.binding_matches?(**base.merge(url: "https://docs.example.com/b"))).to be(false)
    expect(approval.binding_matches?(**base.merge(action_digest: "other"))).to be(false)
  end

  it "enforces an explicit page revision when present" do
    bound = described_class.for_action(actor_id: "actor-1", run_id: "run-1", url: "https://docs.example.com/a",
                                       action: action, page_revision: "rev-1", ttl: 60, now: now)
    base = { actor_id: "actor-1", run_id: "run-1", url: "https://docs.example.com/a",
             action_digest: bound.action_digest }
    expect(bound.binding_matches?(**base, page_revision: "rev-1")).to be(true)
    expect(bound.binding_matches?(**base, page_revision: "rev-2")).to be(false)
  end

  it "consumes once and refuses replay" do
    consumed = approval.consume!(now: now)
    expect(consumed.consumed?).to be(true)
    expect(consumed.active?(now)).to be(false)
    expect { consumed.consume!(now: now) }.to raise_error(RubyLLM::Browser::ApprovalStale, /already consumed/)
  end

  it "can be revoked" do
    expect(approval.revoke!.revoked?).to be(true)
    expect(approval.revoke!.active?(now)).to be(false)
  end

  it "validates inputs" do
    expect { described_class.new(id: "", actor_id: "a", run_id: "r", url: "u", action_digest: "d",
                                 issued_at: now, expires_at: now) }
      .to raise_error(RubyLLM::Browser::InvalidInput, /id/)
    expect { described_class.new(id: "a", actor_id: "a", run_id: "r", url: "u", action_digest: "d",
                                 issued_at: now, expires_at: "soon") }
      .to raise_error(RubyLLM::Browser::InvalidInput, /expires_at/)
  end
end
