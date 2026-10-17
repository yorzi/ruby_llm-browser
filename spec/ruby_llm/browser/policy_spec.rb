# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::Policy do
  subject(:policy) do
    described_class.new(allowed_hosts: [ "docs.example.com" ], resolver: resolver)
  end

  let(:resolver) do
    BrowserSpecSupport::FakeResolver.new("docs.example.com" => [ "93.184.216.34" ])
  end


  describe "#authorize_destination!" do
    it "returns a normalized URI for an allowed host" do
      expect(policy.authorize_destination!("HTTPS://Docs.Example.com/a#f").to_s)
        .to eq("https://docs.example.com/a")
    end

    it "denies disallowed hosts" do
      expect { policy.authorize_destination!("https://other.test/") }
        .to raise_error(RubyLLM::Browser::NotAuthorized)
    end
  end

  describe "#authorize_schema!" do
    let(:schema) do
      { "type" => "object", "properties" => { "title" => { "type" => "string" } },
        "required" => [ "title" ] }
    end

    it "accepts a bounded object schema hash" do
      expect(policy.authorize_schema!(schema)).to eq(schema)
    end

    it "accepts a JSON string schema" do
      expect(policy.authorize_schema!(JSON.generate(schema))).to eq(schema)
    end

    it "accepts an object answering to to_json_schema" do
      schema_object = Object.new
      def schema_object.to_json_schema = { type: "object", properties: {} }
      expect(policy.authorize_schema!(schema_object)).to eq("type" => "object", "properties" => {})
    end

    it "rejects a non-object schema" do
      expect { policy.authorize_schema!("type" => "string") }
        .to raise_error(RubyLLM::Browser::InvalidInput, /object schema/)
    end

    it "rejects unknown schema keys" do
      expect { policy.authorize_schema!("type" => "object", "properties" => {}, "evil" => true) }
        .to raise_error(RubyLLM::Browser::InvalidInput, /unsupported schema key/)
    end

    it "rejects unsupported schema types" do
      expect { policy.authorize_schema!("type" => "object", "properties" => { "x" => { "type" => "exec" } }) }
        .to raise_error(RubyLLM::Browser::InvalidInput, /unsupported schema type/)
    end

    it "rejects too many properties" do
      properties = (1..70).to_h { |i| [ "p#{i}", { "type" => "string" } ] }
      expect { policy.authorize_schema!("type" => "object", "properties" => properties) }
        .to raise_error(RubyLLM::Browser::InvalidInput, /too many properties/)
    end

    it "rejects over-deep schemas" do
      nested = { "type" => "object", "properties" => {} }
      10.times { nested = { "type" => "object", "properties" => { "n" => nested } } }
      expect { policy.authorize_schema!(nested) }
        .to raise_error(RubyLLM::Browser::InvalidInput, /nested too deeply/)
    end

    it "rejects invalid JSON" do
      expect { policy.authorize_schema!("{not json") }
        .to raise_error(RubyLLM::Browser::InvalidInput, /not valid JSON/)
    end
  end

  describe "#authorize_result!" do
    it "redacts secrets and bounds size" do
      data, truncated = policy.authorize_result!({ "api_key" => "sk-1", "title" => "Hi" })
      expect(data).to eq("api_key" => "[REDACTED]", "title" => "Hi")
      expect(truncated).to be(false)

      _, truncated = policy.authorize_result!({ "text" => "x" * 100_000 })
      expect(truncated).to be(true)
    end
  end

  describe "#authorize_action!" do
    it "accepts a narrow, non-sensitive action" do
      action = policy.authorize_action!(
        "description" => "click the download link", "method" => "click", "selector" => "a#dl"
      )
      expect(action["method"]).to eq("click")
      expect(action["selector"]).to eq("a#dl")
    end

    it "rejects methods outside the allowlist" do
      expect { policy.authorize_action!("method" => "evaluate", "selector" => "body") }
        .to raise_error(RubyLLM::Browser::NotAuthorized, /method/)
    end

    it "rejects actions with a missing selector" do
      expect { policy.authorize_action!("method" => "click") }
        .to raise_error(RubyLLM::Browser::InvalidInput, /selector/)
    end

    it "rejects sensitive operations even when the method is allowed" do
      [ "purchase now", "post comment", "delete account", "transfer funds", "sign in" ].each do |description|
        expect do
          policy.authorize_action!("description" => description, "method" => "click", "selector" => "button")
        end.to raise_error(RubyLLM::Browser::NotAuthorized), "expected #{description.inspect} to be denied"
      end
    end

    it "rejects filling a password field" do
      expect do
        policy.authorize_action!("description" => "fill password", "method" => "fill",
                                 "selector" => "input[name=password]", "arguments" => [ "secret" ])
      end.to raise_error(RubyLLM::Browser::NotAuthorized)
    end
  end

  describe "#egress_qualified? / #authorize_egress!" do
    def capabilities(**overrides)
      RubyLLM::Browser::Capabilities.new(**overrides)
    end

    it "requires enforced isolation" do
      expect(policy.egress_qualified?(capabilities(egress_isolation: :enforced))).to be(true)
      expect(policy.egress_qualified?(capabilities)).to be(false)
    end

    it "fails closed for an unqualified backend before start" do
      expect { policy.authorize_egress!(capabilities) }
        .to raise_error(RubyLLM::Browser::UnsupportedSecurityCapability, /egress isolation/)
    end

    it "requires a pinned binary for local mode" do
      unqualified = capabilities(server_mode: :local, egress_isolation: :enforced)
      expect(policy.egress_qualified?(unqualified)).to be(false)

      qualified = capabilities(server_mode: :local, egress_isolation: :enforced, local_binary_pinned: true)
      expect(policy.egress_qualified?(qualified)).to be(true)
    end

    it "requires approval for preset custom headers" do
      unapproved = capabilities(egress_isolation: :enforced, custom_headers_present: true)
      expect(policy.egress_qualified?(unapproved)).to be(false)

      approved = capabilities(egress_isolation: :enforced, custom_headers_present: true,
                              custom_headers_approved: true)
      expect(policy.egress_qualified?(approved)).to be(true)
    end

    it "rejects non-capability arguments" do
      expect(policy.egress_qualified?(:nope)).to be(false)
      expect { policy.authorize_egress!(nil) }
        .to raise_error(RubyLLM::Browser::UnsupportedSecurityCapability, /did not report/)
    end
  end
end
