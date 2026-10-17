# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::Redactor do
  describe ".redact" do
    it "redacts values whose key names look secret" do
      input = {
        "api_key" => "sk-live-123",
        "authorization" => "Bearer abc",
        "Set-Cookie" => "session=1",
        "cdpUrl" => "ws://example/devtools/browser/x",
        "title" => "Welcome"
      }

      expect(described_class.redact(input)).to eq(
        "api_key" => "[REDACTED]",
        "authorization" => "[REDACTED]",
        "Set-Cookie" => "[REDACTED]",
        "cdpUrl" => "[REDACTED]",
        "title" => "Welcome"
      )
    end

    it "keeps ordinary keys such as session_id and product ids" do
      input = { "session_id" => "prod-1", "sku" => "ABC" }
      expect(described_class.redact(input)).to eq(input)
    end

    it "strips DevTools URLs found inside plain strings" do
      expect(described_class.redact("connect ws://127.0.0.1:9222/devtools/browser/abc now"))
        .to eq("connect [REDACTED] now")
    end

    it "removes known secret literals from strings" do
      secret = "sk-verysecret-value"
      expect(described_class.redact("key=#{secret}", secrets: [ secret ])).to eq("key=[REDACTED]")
    end

    it "bounds nesting depth" do
      deep = { "a" => { "b" => { "c" => { "d" => "leaf" } } } }
      redacted = described_class.redact(deep, max_depth: 2)
      expect(redacted["a"]["b"]["c"]).to eq("[REDACTED]")
    end
  end

  describe ".bound" do
    it "returns the value unchanged when it fits" do
      value, truncated = described_class.bound({ "a" => 1 }, max_bytes: 1024)
      expect(value).to eq("a" => 1)
      expect(truncated).to be(false)
    end

    it "returns a marked preview when the value is too large" do
      value, truncated = described_class.bound({ "text" => "x" * 500 }, max_bytes: 64)
      expect(truncated).to be(true)
      expect(value["truncated"]).to be(true)
      expect(value["preview"].bytesize).to be <= 64
    end
  end

  describe ".digest" do
    it "is stable regardless of key order" do
      expect(described_class.digest("a" => 1, "b" => 2)).to eq(described_class.digest("b" => 2, "a" => 1))
    end

    it "changes when content changes" do
      expect(described_class.digest("a" => 1)).not_to eq(described_class.digest("a" => 2))
    end
  end
end
