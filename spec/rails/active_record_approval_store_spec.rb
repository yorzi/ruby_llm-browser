# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::Rails::ActiveRecordApprovalStore do
  subject(:store) { described_class.new }

  let(:action) do
    { "method" => "click", "selector" => "#go", "description" => "go", "arguments" => [] }
  end
  let(:url) { "https://docs.example.com/page" }

  def issue(**overrides)
    approval = RubyLLM::Browser::Approval.for_action(
      actor_id: "actor-1", run_id: "run-1", url: url, action: action, ttl: 300,
      now: fixed_time, **overrides
    )
    store.issue(approval)
    approval
  end

  def consume(approval, **overrides)
    store.consume_once(
      approval.id, actor_id: "actor-1", run_id: "run-1", url: url,
      action_digest: approval.action_digest, now: fixed_time, **overrides
    )
  end

  describe "#issue and #fetch" do
    it "round-trips an approval including its normalized action" do
      approval = issue

      fetched = store.fetch(approval.id)

      expect(fetched.id).to eq(approval.id)
      expect(fetched.action).to eq(action)
      expect(fetched.expires_at).to eq(approval.expires_at)
      expect(fetched).not_to be_consumed
    end

    it "rejects a duplicate id" do
      approval = issue

      expect { store.issue(approval) }
        .to raise_error(RubyLLM::Browser::InvalidInput, /already exists/)
    end
  end

  describe "#consume_once" do
    it "consumes exactly once and refuses a replay" do
      approval = issue

      consumed = consume(approval)

      expect(consumed).to be_consumed
      expect(store.fetch(approval.id)).to be_consumed
      expect { consume(approval) }
        .to raise_error(RubyLLM::Browser::ApprovalStale, /already consumed/)
    end

    it "raises ApprovalRequired for an unknown id" do
      expect { store.consume_once("apr-missing", actor_id: "actor-1", run_id: "run-1",
                                                    url: url, action_digest: "x", now: fixed_time) }
        .to raise_error(RubyLLM::Browser::ApprovalRequired)
    end

    it "refuses a cross-actor approval without consuming it" do
      approval = issue

      expect { consume(approval, actor_id: "someone-else") }
        .to raise_error(RubyLLM::Browser::ApprovalStale, /does not authorize/)
      expect(store.fetch(approval.id)).not_to be_consumed
    end

    it "refuses an expired approval" do
      approval = issue(ttl: 0)

      expect { consume(approval) }
        .to raise_error(RubyLLM::Browser::ApprovalStale, /expired/)
    end

    it "refuses a revoked approval" do
      approval = issue
      store.revoke(approval.id)

      expect { consume(approval) }
        .to raise_error(RubyLLM::Browser::ApprovalStale, /revoked/)
    end

    it "refuses a different page revision or action digest" do
      pinned = issue(page_revision: "rev-a")

      expect { consume(pinned, page_revision: "rev-b") }
        .to raise_error(RubyLLM::Browser::ApprovalStale, /does not authorize/)
      expect { consume(pinned, action_digest: "different") }
        .to raise_error(RubyLLM::Browser::ApprovalStale, /does not authorize/)
      expect(store.fetch(pinned.id)).not_to be_consumed
    end
  end
end
