# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::Capabilities do
  subject(:capabilities) { described_class.new }

  it "defaults to a conservative remote posture" do
    expect(capabilities.server_mode).to eq(:remote)
    expect(capabilities.egress_isolation).to eq(:unverified)
    expect(capabilities).not_to be_enforced_egress
    expect(capabilities).not_to be_act_supported
    expect(capabilities).not_to be_local_mode
  end

  it "reports helper predicates" do
    local = described_class.new(server_mode: :local, local_binary_pinned: true,
                                egress_isolation: :enforced, custom_headers_present: true,
                                custom_headers_approved: true, act_supported: true)
    expect(local).to be_local_mode
    expect(local).to be_enforced_egress
    expect(local).to be_local_binary_pinned
    expect(local).to be_custom_headers_present
    expect(local).to be_custom_headers_approved
    expect(local).to be_act_supported
  end

  it "is immutable and digestible" do
    expect(capabilities).to be_frozen
    expect(capabilities.digest).to eq(described_class.new.digest)
    expect(capabilities).to eq(described_class.new)
  end

  it "validates its enumerations" do
    expect { described_class.new(server_mode: :quantum) }
      .to raise_error(RubyLLM::Browser::InvalidInput, /server_mode/)
    expect { described_class.new(egress_isolation: :maybe) }
      .to raise_error(RubyLLM::Browser::InvalidInput, /egress_isolation/)
  end
end
