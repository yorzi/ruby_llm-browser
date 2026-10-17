# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::Configuration do
  subject(:configuration) { described_class.new }

  it "provides safe defaults" do
    expect(configuration.backend).to be_nil
    expect(configuration.default_budget).to be_a(RubyLLM::Browser::Budget)
    expect(configuration.max_result_bytes).to be_a(Integer)
    expect(configuration.now).to be_a(Time)
    expect(configuration.now.utc?).to be(true)
  end

  it "validates the clock" do
    expect { configuration.clock = 5 }.to raise_error(RubyLLM::Browser::InvalidInput)
    configuration.clock = -> { Time.utc(2020, 1, 1) }
    expect(configuration.now).to eq(Time.utc(2020, 1, 1))
  end

  it "validates max_result_bytes" do
    expect { configuration.max_result_bytes = 0 }.to raise_error(RubyLLM::Browser::InvalidInput)
    configuration.max_result_bytes = 100
    expect(configuration.max_result_bytes).to eq(100)
  end

  it "validates the default budget type" do
    expect { configuration.default_budget = :nope }.to raise_error(RubyLLM::Browser::InvalidInput)
  end

  it "is reset through the module API" do
    RubyLLM::Browser.configure { |config| config.max_result_bytes = 123 }
    expect(RubyLLM::Browser.configuration.max_result_bytes).to eq(123)

    RubyLLM::Browser.reset_configuration!
    expect(RubyLLM::Browser.configuration.max_result_bytes).to eq(described_class::DEFAULT_MAX_RESULT_BYTES)
  end
end
