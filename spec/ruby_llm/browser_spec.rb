# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser do
  it "has a version number" do
    expect(RubyLLM::Browser::VERSION).not_to be_nil
  end
end
