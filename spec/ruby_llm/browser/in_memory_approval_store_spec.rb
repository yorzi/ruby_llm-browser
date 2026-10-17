# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::InMemoryApprovalStore do
  let(:now) { Time.utc(2026, 10, 17, 12, 0, 0) }
  let(:store) { described_class.new }
  let(:action) do
    { "description" => "click download", "method" => "click", "selector" => "a#dl", "arguments" => [] }
  end

  def issue(**overrides)
    store.issue(
      RubyLLM::Browser::Approval.for_action(
        actor_id: "actor-1", run_id: "run-1", url: "https://docs.example.com/a",
        action: action, ttl: 60, now: now, **overrides
      )
    )
  end

  def consume(id, **overrides)
    store.consume_once(id, actor_id: "actor-1", run_id: "run-1", url: "https://docs.example.com/a",
                           action_digest: RubyLLM::Browser::Approval.action_digest(action), now: now,
                           **overrides)
  end

  it "issues and reads without consuming" do
    approval = issue
    expect(store.fetch(approval.id)).to eq(approval)
    store.fetch(approval.id)
    expect(store.fetch(approval.id).consumed?).to be(false)
  end

  it "consumes exactly once" do
    approval = issue
    consumed = consume(approval.id)
    expect(consumed.consumed?).to be(true)
    expect { consume(approval.id) }
      .to raise_error(RubyLLM::Browser::ApprovalStale, /already consumed/)
  end

  it "requires a matching approval" do
    expect { consume("apr_missing") }
      .to raise_error(RubyLLM::Browser::ApprovalRequired)
  end

  it "refuses an expired approval" do
    approval = store.issue(
      RubyLLM::Browser::Approval.for_action(actor_id: "actor-1", run_id: "run-1",
                                            url: "https://docs.example.com/a", action: action,
                                            ttl: 1, now: now)
    )
    expect { consume(approval.id, now: now + 5) }
      .to raise_error(RubyLLM::Browser::ApprovalStale, /expired/)
  end

  it "refuses a cross-actor approval" do
    approval = issue
    expect { consume(approval.id, actor_id: "actor-2") }
      .to raise_error(RubyLLM::Browser::ApprovalStale, /does not authorize/)
  end

  it "refuses a changed URL, page revision or action digest" do
    revision = issue(page_revision: "rev-1")
    expect { consume(revision.id, url: "https://docs.example.com/b") }
      .to raise_error(RubyLLM::Browser::ApprovalStale)
    expect { consume(revision.id, page_revision: "rev-2") }
      .to raise_error(RubyLLM::Browser::ApprovalStale)
    expect { consume(revision.id, action_digest: "other") }
      .to raise_error(RubyLLM::Browser::ApprovalStale)
  end

  it "refuses a revoked approval" do
    approval = issue
    store.revoke(approval.id)
    expect { consume(approval.id) }
      .to raise_error(RubyLLM::Browser::ApprovalStale, /revoked/)
  end

  it "refuses a duplicate issue" do
    approval = issue
    expect { store.issue(approval) }.to raise_error(RubyLLM::Browser::InvalidInput, /already exists/)
  end
end
