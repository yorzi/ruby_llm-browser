# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::Error do
  {
    RubyLLM::Browser::InvalidInput => "INVALID_INPUT",
    RubyLLM::Browser::NotAuthorized => "NOT_AUTHORIZED",
    RubyLLM::Browser::UnsupportedSecurityCapability => "UNSUPPORTED_SECURITY_CAPABILITY",
    RubyLLM::Browser::BudgetExhausted => "BUDGET_EXHAUSTED",
    RubyLLM::Browser::SessionUnknown => "SESSION_UNKNOWN",
    RubyLLM::Browser::CleanupPending => "CLEANUP_PENDING",
    RubyLLM::Browser::ApprovalRequired => "APPROVAL_REQUIRED",
    RubyLLM::Browser::ApprovalStale => "APPROVAL_STALE",
    RubyLLM::Browser::ProviderError => "PROVIDER_ERROR"
  }.each do |klass, code|
    it "gives #{klass} #{code}" do
      error = klass.new("nope")
      expect(error).to be_a(described_class)
      expect(error.code).to eq(code)
      expect(error.to_h).to eq(code: code, message: "nope")
    end
  end

  it "defaults the base error code" do
    expect(described_class.new("boom").code).to eq("ERROR")
  end
end
