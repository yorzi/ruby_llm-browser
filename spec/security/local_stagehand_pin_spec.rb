# frozen_string_literal: true

require "spec_helper"
require "digest"
require "tmpdir"
require "stagehand"

RSpec.describe RubyLLM::Browser::StagehandBackend do
  let(:directory) { Dir.mktmpdir("stagehand-pin") }
  let(:binary) { File.join(directory, "server") }

  around do |example|
    original = ENV["STAGEHAND_SEA_BINARY"]
    File.write(binary, "#!/bin/sh\nexit 99\n")
    File.chmod(0o700, binary)
    ENV["STAGEHAND_SEA_BINARY"] = binary
    example.run
  ensure
    original.nil? ? ENV.delete("STAGEHAND_SEA_BINARY") : ENV["STAGEHAND_SEA_BINARY"] = original
    FileUtils.remove_entry(directory)
  end

  def backend(**options)
    RubyLLM::Browser::StagehandBackend.new(
      browserbase_api_key: "fixture-key", model_api_key: "fixture-key", model_name: "fixture-model",
      server: :local, env: ENV, **options
    )
  end

  def checksum = Digest::SHA256.file(binary).hexdigest

  it "does not accept a version label as executable identity" do
    ENV.delete("STAGEHAND_SEA_BINARY")
    local = backend(env: { "STAGEHAND_SERVER_VERSION" => "3.21.0" })

    expect(local.capabilities.local_binary_pinned?).to be(false)
  end

  it "does not accept a path without a host-supplied checksum" do
    expect(backend.capabilities.local_binary_pinned?).to be(false)
  end

  it "verifies an executable without executing it or enabling live use" do
    local = backend(server_binary_sha256: checksum)
    allow(Stagehand::Client).to receive(:new).and_call_original

    expect(local.capabilities.local_binary_pinned?).to be(true)
    report = RubyLLM::Browser::Doctor.new(backend: local).report
    expect(report[:checks].find { |item| item[:name] == :local_binary }[:status]).to eq(:pass)
    expect(report[:ok]).to be(false)
    expect(local.capabilities.egress_isolation).to eq(:unverified)
    expect(local.capabilities.act_supported?).to be(false)
    expect(Stagehand::Client).not_to have_received(:new)
  end

  it "rejects malformed checksums without echoing the supplied value" do
    [ "latest", "a" * 63, "G" * 64, 123 ].each do |value|
      expect { backend(server_binary_sha256: value) }
        .to raise_error(RubyLLM::Browser::InvalidInput, "server_binary_sha256 must be a lowercase SHA-256 digest")
    end
  end

  it "fails closed for a checksum mismatch" do
    expect(backend(server_binary_sha256: "0" * 64).capabilities.local_binary_pinned?).to be(false)
  end

  it "requires a regular executable file" do
    digest = checksum
    File.chmod(0o600, binary)
    expect(backend(server_binary_sha256: digest).capabilities.local_binary_pinned?).to be(false)
    File.unlink(binary)
    expect(backend(server_binary_sha256: digest).capabilities.local_binary_pinned?).to be(false)
    Dir.mkdir(binary)
    expect(backend(server_binary_sha256: digest).capabilities.local_binary_pinned?).to be(false)
  end

  it "refuses a relative executable path" do
    ENV["STAGEHAND_SEA_BINARY"] = "relative-server"
    expect(backend(server_binary_sha256: checksum).capabilities.local_binary_pinned?).to be(false)
  end

  it "does not treat an injected environment as the SDK process environment" do
    ENV.delete("STAGEHAND_SEA_BINARY")
    local = backend(server_binary_sha256: checksum, env: { "STAGEHAND_SEA_BINARY" => binary })

    expect(local.capabilities.local_binary_pinned?).to be(false)
  end

  it "detects replacement of bytes at the same executable path" do
    local = backend(server_binary_sha256: checksum)
    expect(local.capabilities.local_binary_pinned?).to be(true)
    File.write(binary, "#!/bin/sh\nexit 98\n")

    expect(local.capabilities.local_binary_pinned?).to be(false)
    expect(RubyLLM::Browser::Doctor.new(backend: local).report[:checks]
      .find { |item| item[:name] == :local_binary }[:status]).to eq(:fail)
  end

  it "rechecks identity before constructing the SDK client" do
    local = backend(server_binary_sha256: checksum)
    File.write(binary, "#!/bin/sh\nexit 98\n")
    allow(Stagehand::Client).to receive(:new)

    expect { local.send(:client) }.to raise_error(RubyLLM::Browser::UnsupportedSecurityCapability, /checksum/)
    expect(Stagehand::Client).not_to have_received(:new)
  end

  it "copies the caller's checksum so mutation cannot approve replacement bytes" do
    digest = checksum
    local = backend(server_binary_sha256: digest)
    File.write(binary, "#!/bin/sh\nexit 98\n")
    digest.replace(checksum)

    expect(local.capabilities.local_binary_pinned?).to be(false)
    expect(digest).not_to be_frozen
  end

  it "blocks calls without constructing or downloading a server even with a valid binary" do
    local = backend(server_binary_sha256: checksum)
    allow(Stagehand::Client).to receive(:new)

    expect { local.start(context: build_context(backend: local), operation: build_operation, now: fixed_time) }
      .to raise_error(RubyLLM::Browser::UnsupportedSecurityCapability)
    expect(Stagehand::Client).not_to have_received(:new)
  end
end
