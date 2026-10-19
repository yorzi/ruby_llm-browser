# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::Result do
  let(:time) { Time.utc(2026, 10, 17, 12, 0, 0) }

  describe ".ok" do
    it "builds an ok result and serializes times as ISO 8601" do
      result = described_class.ok(
        data: { "title" => "Hi" }, operation_id: "op-1", final_url: "https://example.com",
        captured_at: time, locator: { "url" => "https://example.com" }, digest: "abc"
      )

      expect(result).to be_ok
      expect(result.status).to eq(:ok)
      expect(result.to_h).to include(
        status: "ok", operation_id: "op-1", final_url: "https://example.com",
        captured_at: "2026-10-17T12:00:00Z", digest: "abc", truncated: false
      )
      expect(JSON.parse(result.to_json)).to include("status" => "ok")
    end

    it "marks truncated results" do
      result = described_class.ok(data: {}, truncated: true)
      expect(result.status).to eq(:truncated)
      expect(result.truncated?).to be(true)
      expect(result).to be_ok
    end
  end

  describe ".failure" do
    it "carries a typed error and no truth claim" do
      result = described_class.failure(:error, error_code: "PROVIDER_ERROR", message: "429")

      expect(result).not_to be_ok
      expect(result.to_h[:error]).to eq(code: "PROVIDER_ERROR", message: "429")
      expect(result.to_h).not_to have_key(:captured_at)
    end
  end

  it "rejects unknown statuses" do
    expect { described_class.new(status: :exploded) }.to raise_error(RubyLLM::Browser::InvalidInput)
  end

  it "copies and freezes failure identity and error strings retained for delivery" do
    id, code, message = %w[op-1 PROVIDER_ERROR safe].map(&:dup)
    result = described_class.failure(:error, operation_id: id, error_code: code, message: message)
    id.replace("different")
    code.replace("different")
    message.replace("changed")

    expect(result.to_h).to include(operation_id: "op-1", error: { code: "PROVIDER_ERROR", message: "safe" })
    expect([ id, code, message ]).not_to include(be_frozen)
    expect { result.error_message.replace("changed") }.to raise_error(FrozenError)
    expect { result.operation_id.replace("changed") }.to raise_error(FrozenError)
    expect { result.error_code.replace("changed") }.to raise_error(FrozenError)
  end

  it "destructures as its model-safe hash" do
    result = described_class.ok(data: { "x" => 1 })
    expect(result.deconstruct_keys(nil)).to eq(result.to_h)
  end
end
