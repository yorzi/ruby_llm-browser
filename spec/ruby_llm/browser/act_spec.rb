# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::Act do
  subject(:tool) { described_class.new(context: context) }

  let(:backend) { RubyLLM::Browser::FakeBackend.new }
  let(:policy) { build_policy }
  let(:store) { RubyLLM::Browser::InMemoryOperationStore.new }
  let(:approval_store) { RubyLLM::Browser::InMemoryApprovalStore.new }
  let(:context) do
    build_context(backend: backend, policy: policy, operation_store: store,
                  approval_store: approval_store)
  end
  let(:url) { "https://docs.example.com/a" }
  let(:action) { policy.authorize_action!("method" => "click", "selector" => "a#docs") }

  def tool_call(approval_id)
    RubyLLM::ToolCall.new(id: "call-1", name: "browser_act",
                          arguments: { "approval_id" => approval_id })
  end

  it "is opt-in: declared to require approval with a stable name" do
    expect(tool.name).to eq("browser_act")
    expect(tool.requires_approval?).to be(true)
  end

  it "exposes only the action fields, not a schema or a page revision" do
    schema = tool.parameters_schema
    expect(schema["properties"].keys)
      .to contain_exactly("url", "approval_id", "method", "selector", "description", "arguments")
    expect(schema["required"]).to contain_exactly("url", "approval_id", "method", "selector")
  end

  describe "#approval_resolver" do
    it "reads the host store without consuming and allows a bound approval" do
      approval = build_approval(approval_store, context: context, url: url, action: action)

      expect(tool.approval_resolver.call(tool_call(approval.id))).to be(true)
      expect(approval_store.fetch(approval.id)).not_to be_consumed
    end

    it "denies when no matching host approval exists" do
      expect(tool.approval_resolver.call(tool_call("apr-missing"))).to be(false)
    end

    it "denies a cross-actor approval" do
      foreign = RubyLLM::Browser::Approval.for_action(
        actor_id: "someone-else", run_id: context.run_id, url: url, action: action,
        ttl: 300, now: fixed_time
      )
      approval_store.issue(foreign)
      expect(tool.approval_resolver.call(tool_call(foreign.id))).to be(false)
    end

    it "denies expired and consumed approvals" do
      expired = build_approval(approval_store, context: context, url: url, action: action, ttl: 0)
      expect(tool.approval_resolver.call(tool_call(expired.id))).to be(false)

      consumed = build_approval(approval_store, context: context, url: url, action: action)
      approval_store.consume_once(consumed.id, actor_id: context.actor_id, run_id: context.run_id,
                                  url: url, action_digest: consumed.action_digest, now: fixed_time)
      expect(tool.approval_resolver.call(tool_call(consumed.id))).to be(false)
    end

    it "denies everything when no approval store is configured" do
      bare = described_class.new(context: build_context(backend: backend, operation_store: store))
      expect(bare.approval_resolver.call(tool_call("apr-1"))).to be(false)
    end
  end

  describe "#execute" do
    it "dispatches exactly one approved action" do
      approval = build_approval(approval_store, context: context, url: url, action: action)
      result = tool.call(url: url, approval_id: approval.id, method: "click", selector: "a#docs")

      expect(result[:status]).to eq("ok")
      expect(result[:locator]).to include("approval_id" => approval.id)
      expect(backend.call_count(:act)).to eq(1)
      expect(approval_store.fetch(approval.id)).to be_consumed
    end

    it "returns a safe error hash when the approval is missing" do
      result = tool.call(url: url, approval_id: "apr-missing", method: "click", selector: "a#docs")
      expect(result[:status]).to eq("error")
      expect(result[:error][:code]).to eq("APPROVAL_REQUIRED")
      expect(backend.call_count(:act)).to eq(0)
    end

    it "refuses a sensitive action before any session" do
      result = tool.call(url: url, approval_id: "apr-1", method: "click", selector: "button",
                         description: "purchase now")
      expect(result[:error][:code]).to eq("NOT_AUTHORIZED")
      expect(backend.call_count(:start)).to eq(0)
    end
  end

  describe "RubyLLM integration" do
    before do
      RubyLLM.configure { |config| config.openai_api_key = "sk-test-not-a-real-key" }
    end

    it "lets a bare Chat#approve dispatch nothing without a host grant" do
      chat = RubyLLM::Chat.new(model: "gpt-4o-mini")
      chat.with_tools(tool)
      call = tool_call("apr-missing")

      chat.add_message(role: :assistant, content: nil, tool_calls: { call.id => call })
      chat.approve(call)
      chat.run_tools
      expect(backend.call_count(:act)).to eq(0)
      expect(chat.messages.last.role).to eq(:tool)
    end

    it "permits the call once a host grant exists, without consuming it early" do
      approval = build_approval(approval_store, context: context, url: url, action: action)
      chat = RubyLLM::Chat.new(model: "gpt-4o-mini")
      chat.with_tools(tool)

      call = RubyLLM::ToolCall.new(id: "call-1", name: "browser_act", arguments: {
        "url" => url, "approval_id" => approval.id, "method" => "click", "selector" => "a#docs"
      })
      chat.add_message(role: :assistant, content: nil, tool_calls: { call.id => call })
      expect(chat.awaiting_approval?).to be(false)
      expect(approval_store.fetch(approval.id)).not_to be_consumed
      chat.run_tools
      expect(backend.call_count(:act)).to eq(1)
      expect(approval_store.fetch(approval.id)).to be_consumed
    end
  end
end
