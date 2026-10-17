# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::Backend do
  subject(:backend) { described_class.new }

  it "reports no secret literals by default" do
    expect(backend.secrets).to eq([])
  end

  it "defaults reconciliation to an unconfirmed outcome" do
    expect(backend.reconcile(nil, now: Time.utc(2026, 10, 17))).to eq(:unknown)
  end

  it "forces every implementation point to be overridden" do
    operation = instance_double(RubyLLM::Browser::Operation, id: "op-1")
    context = instance_double(RubyLLM::Browser::Context, actor_id: "a", run_id: "r", backend: backend)
    now = Time.utc(2026, 10, 17)

    expect { backend.capabilities }.to raise_error(NotImplementedError)
    expect { backend.start(context: context, operation: operation, now: now) }
      .to raise_error(NotImplementedError)
    expect { backend.navigate(nil, url: "https://docs.example.com/", operation: operation, now: now) }
      .to raise_error(NotImplementedError)
    expect { backend.observe(nil, instruction: nil, operation: operation, now: now) }
      .to raise_error(NotImplementedError)
    expect { backend.extract(nil, schema: {}, instruction: nil, operation: operation, now: now) }
      .to raise_error(NotImplementedError)
    expect { backend.act(nil, action: {}, operation: operation, now: now) }
      .to raise_error(NotImplementedError)
    expect { backend.end_session(nil, operation: operation, now: now) }
      .to raise_error(NotImplementedError)
  end
end
