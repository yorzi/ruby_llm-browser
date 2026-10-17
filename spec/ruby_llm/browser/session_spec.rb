# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::Session do
  subject(:session) { described_class.new(id: "sess-1", url: "https://docs.example.com/", started_at: now) }

  let(:now) { Time.utc(2026, 10, 17, 12, 0, 0) }

  it "exposes only id, url and start time" do
    expect(session.id).to eq("sess-1")
    expect(session.url).to eq("https://docs.example.com/")
    expect(session.started_at).to eq(now)
  end

  it "has no reader for a DevTools cdp_url" do
    expect(session).not_to respond_to(:cdp_url)
  end

  it "returns an updated copy when the URL changes" do
    moved = session.with_url("https://docs.example.com/other")
    expect(moved.url).to eq("https://docs.example.com/other")
    expect(session.url).to eq("https://docs.example.com/")
    expect(moved).to be_frozen
  end

  it "serializes times as ISO 8601 UTC" do
    expect(session.to_h).to eq(id: "sess-1", url: "https://docs.example.com/",
                               started_at: "2026-10-17T12:00:00Z")
  end

  it "rejects an empty id" do
    expect { described_class.new(id: "") }
      .to raise_error(RubyLLM::Browser::InvalidInput, /session id/)
  end
end
