# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"
require "yaml"
require "open3"

RSpec.describe "release metadata gate" do
  let(:directory) { Dir.mktmpdir("browser-release-") }

  around do |example|
    root = File.expand_path("../..", __dir__)
    %w[bin/verify-release lib/ruby_llm/browser/version.rb ruby_llm-browser.gemspec].each do |path|
      FileUtils.mkdir_p(File.dirname(File.join(directory, path)))
      FileUtils.cp(File.join(root, path), File.join(directory, path))
    end
    FileUtils.mkdir_p(File.join(directory, "docs"))
    File.write(File.join(directory, "CHANGELOG.md"), "## [Unreleased]\n")
    write_config(released: false)
    example.run
  ensure
    FileUtils.remove_entry(directory)
  end

  def write_config(released:, version: RubyLLM::Browser::VERSION)
    File.write(File.join(directory, "docs/_config.yml"), { "version" => version, "released" => released }.to_yaml)
  end

  def verify(*arguments, tag: nil)
    Open3.capture3({ "GITHUB_REF_NAME" => tag, "GITHUB_REF_TYPE" => tag ? "tag" : nil },
                   RbConfig.ruby, File.join(directory, "bin/verify-release"), *arguments)
  end

  it "accepts an unreleased candidate but refuses it as a release" do
    stdout, stderr, status = verify("--candidate")
    expect(status).to be_success, stderr
    expect(stdout).to include("CANDIDATE_METADATA_PASS")
    _, stderr, status = verify
    expect(status).not_to be_success
    expect(stderr).to include("not marked released")
  end

  it "rejects mismatched docs versions" do
    write_config(released: false, version: "0.0.1")
    _, stderr, status = verify("--candidate")
    expect(status).not_to be_success
    expect(stderr).to include("Docs version does not match")
  end

  it "requires dated notes and a matching tag for a release" do
    write_config(released: true)
    _, stderr, status = verify
    expect(status).not_to be_success
    expect(stderr).to include("Missing dated")
    version = RubyLLM::Browser::VERSION
    File.write(File.join(directory, "CHANGELOG.md"), "## [#{version}] - 2026-10-19\n")
    _, stderr, status = verify(tag: "v0.0.1")
    expect(status).not_to be_success
    expect(stderr).to include("Tag does not match")
    stdout, stderr, status = verify(tag: "v#{version}")
    expect(status).to be_success, stderr
    expect(stdout).to include("RELEASE_METADATA_PASS")
  end
end
