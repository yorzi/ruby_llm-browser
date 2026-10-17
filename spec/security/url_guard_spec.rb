# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::Browser::UrlGuard do
  subject(:guard) do
    described_class.new(allowed_hosts: allowed_hosts, resolver: resolver)
  end

  let(:resolver) do
    BrowserSpecSupport::FakeResolver.new(
      "example.com" => [ "93.184.216.34" ],
      "docs.example.com" => [ "93.184.216.34" ],
      "a.example.org" => [ "93.184.216.34" ],
      "a.b.example.org" => [ "93.184.216.34" ],
      "rebind.example.com" => [ "93.184.216.34", "10.0.0.7" ],
      "internal.example.com" => [ "192.168.1.10" ]
    )
  end

  let(:allowed_hosts) { [ "example.com", "docs.example.com", "*.example.org", "public.test" ] }

  describe "#authorize!" do
    it "normalizes scheme, host, default port and drops the fragment" do
      uri = guard.authorize!("HTTP://Example.COM:80/a?b=1#frag")
      expect(uri.to_s).to eq("http://example.com/a?b=1")
      expect(uri).to be_frozen
    end

    it "adds a root path when none is given" do
      expect(guard.authorize!("https://example.com").to_s).to eq("https://example.com/")
    end

    it "allows exact allowlist hosts" do
      expect { guard.authorize!("https://example.com/page") }.not_to raise_error
    end

    it "allows wildcard subdomains but not the bare domain" do
      expect { guard.authorize!("https://a.example.org/") }.not_to raise_error
      expect { guard.authorize!("https://a.b.example.org/") }.not_to raise_error
      expect { guard.authorize!("https://example.org/") }
        .to raise_error(RubyLLM::Browser::NotAuthorized)
    end

    it "denies hosts outside the source list" do
      expect { guard.authorize!("https://evil.test/") }
        .to raise_error(RubyLLM::Browser::NotAuthorized, /allowed source list/)
    end

    it "denies URLs with userinfo" do
      expect { guard.authorize!("https://user:pass@example.com/") }
        .to raise_error(RubyLLM::Browser::NotAuthorized, /userinfo/)
    end

    it "denies non-http(s) schemes" do
      expect { guard.authorize!("ftp://example.com/x") }
        .to raise_error(RubyLLM::Browser::NotAuthorized, /scheme/)
      expect { guard.authorize!("file:///etc/passwd") }
        .to raise_error(RubyLLM::Browser::NotAuthorized)
    end

    it "denies non-approved ports" do
      expect { guard.authorize!("https://example.com:8080/x") }
        .to raise_error(RubyLLM::Browser::NotAuthorized, /port/)
    end

    it "denies loopback, private, link-local and metadata literals" do
      [ "http://127.0.0.1/", "http://10.0.0.5/", "http://192.168.0.1/",
       "http://169.254.169.254/latest/meta-data/", "http://172.16.0.1/",
       "http://0.0.0.0/", "http://[::1]/", "http://[fe80::1]/", "http://[fc00::1]/",
       "http://[::ffff:10.0.0.1]/" ].each do |url|
        expect { described_class.new(allowed_hosts: [ "127.0.0.1", "10.0.0.5", "192.168.0.1",
                                                     "169.254.169.254", "172.16.0.1", "0.0.0.0",
                                                     "::1", "fe80::1", "fc00::1", "::ffff:10.0.0.1" ],
                                     verify_dns: false).authorize!(url) }
          .to raise_error(RubyLLM::Browser::NotAuthorized), "expected #{url} to be denied"
      end
    end

    it "denies ambiguous integer and non-canonical IPv4 encodings" do
      [ "http://2130706433/", "http://0x7f.0.0.1/", "http://127.1/", "http://0177.0.0.1/" ].each do |url|
        expect { guard.authorize!(url) }
          .to raise_error(RubyLLM::Browser::InvalidInput, /ambiguous/), "expected #{url} to be ambiguous"
      end
    end

    it "denies internationalized hosts" do
      expect { guard.authorize!("https://exämple.com/") }
        .to raise_error(RubyLLM::Browser::InvalidInput, /internationalized|valid URI/)
    end

    it "denies a host that resolves to a mixed private/public answer" do
      expect { described_class.new(allowed_hosts: [ "rebind.example.com" ], resolver: resolver)
        .authorize!("https://rebind.example.com/") }
        .to raise_error(RubyLLM::Browser::NotAuthorized, /non-public/)
    end

    it "denies a host that only resolves to a private address" do
      expect { described_class.new(allowed_hosts: [ "internal.example.com" ], resolver: resolver)
        .authorize!("https://internal.example.com/") }
        .to raise_error(RubyLLM::Browser::NotAuthorized, /non-public/)
    end

    it "denies an unresolvable host" do
      expect { described_class.new(allowed_hosts: [ "missing.example.com" ], resolver: resolver)
        .authorize!("https://missing.example.com/") }
        .to raise_error(RubyLLM::Browser::NotAuthorized, /did not resolve/)
    end

    it "rejects malformed input" do
      expect { guard.authorize!("not a url") }.to raise_error(RubyLLM::Browser::InvalidInput)
      expect { guard.authorize!(nil) }.to raise_error(RubyLLM::Browser::InvalidInput)
      expect { guard.authorize!("https://") }.to raise_error(RubyLLM::Browser::InvalidInput)
    end
  end

  describe "allowlist validation" do
    it "requires at least one entry" do
      expect { described_class.new(allowed_hosts: []) }.to raise_error(RubyLLM::Browser::InvalidInput)
    end

    it "rejects entries with schemes or paths" do
      expect { described_class.new(allowed_hosts: [ "https://example.com" ]) }
        .to raise_error(RubyLLM::Browser::InvalidInput)
    end
  end

  describe "#private_address?" do
    it "is true for reserved addresses and unparseable input" do
      expect(guard.private_address?("127.0.0.1")).to be(true)
      expect(guard.private_address?("8.8.8.8")).to be(false)
      expect(guard.private_address?("nonsense")).to be(true)
    end
  end
end
