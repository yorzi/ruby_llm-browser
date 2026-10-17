# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::Budget do
  subject(:budget) { described_class.new(max_seconds: 30, max_steps: 5, max_bytes: 1024, max_concurrent: 2) }

  it "exposes its limits" do
    expect(budget.max_seconds).to eq(30)
    expect(budget.max_steps).to eq(5)
    expect(budget.max_bytes).to eq(1024)
    expect(budget.max_concurrent).to eq(2)
    expect(budget.max_cost_usd).to be_nil
  end

  it "is immutable" do
    expect(budget).to be_frozen
    expect { budget.max_steps = 1 }.to raise_error(NoMethodError)
  end

  it "digests its limits deterministically" do
    same = described_class.new(max_seconds: 30, max_steps: 5, max_bytes: 1024, max_concurrent: 2)
    expect(budget.digest).to eq(same.digest)
    expect(budget).to eq(same)
  end

  it "validates positive integers" do
    expect { described_class.new(max_steps: 0) }.to raise_error(RubyLLM::Browser::InvalidInput, /max_steps/)
    expect { described_class.new(max_seconds: -1) }.to raise_error(RubyLLM::Browser::InvalidInput, /max_seconds/)
    expect { described_class.new(max_bytes: 1.5) }.to raise_error(RubyLLM::Browser::InvalidInput, /max_bytes/)
    expect { described_class.new(max_concurrent: "1") }
      .to raise_error(RubyLLM::Browser::InvalidInput, /max_concurrent/)
  end

  it "accepts an advisory cost reservation" do
    expect(described_class.new(max_cost_usd: 0.5).max_cost_usd).to eq(0.5)
  end
end
