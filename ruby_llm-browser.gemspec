# frozen_string_literal: true

require_relative "lib/ruby_llm/browser/version"

Gem::Specification.new do |spec|
  spec.name = "ruby_llm-browser"
  spec.version = RubyLLM::Browser::VERSION
  spec.authors = [ "Andy Wang" ]
  spec.email = [ "wangyaodi@gmail.com" ]

  spec.summary = "Policy-bound browser Inspect/Extract tools for RubyLLM, backed by the official Stagehand Ruby SDK."
  spec.description = <<~DESCRIPTION
    An unofficial community extension for RubyLLM. It adds policy-bound, read-only
    browser Inspect and Extract tools built on the official Stagehand Ruby SDK, with
    explicit URL/SSRF policy, bounded and sanitized results with provenance, durable
    operation and session lifecycle bookkeeping, budgets, experimental offline Act
    simulation, and an optional Rails 8 / Active Job adapter. The Gem core works in plain
    Ruby without Rails.
  DESCRIPTION

  spec.homepage = "https://github.com/yorzi/ruby_llm-browser"
  spec.license = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.2")

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.glob("{lib,docs,examples}/**/*").select { |file| File.file?(file) } +
               %w[README.md CHANGELOG.md LICENSE.txt NOTICE.md SECURITY.md CONTRIBUTING.md CODE_OF_CONDUCT.md]
  spec.require_paths = [ "lib" ]

  # RubyLLM owns the Tool and chat execution loop; this Gem only adds browser tools.
  spec.add_dependency "ruby_llm", ">= 2.0", "< 3"
  spec.add_dependency "json_schemer", "~> 2.5"

  # Ruby's old bundled/default gems can otherwise satisfy transitive dependencies
  # with known DNS, URL, CGI and compression vulnerabilities on a clean install.
  spec.add_dependency "cgi", ">= 0.4.2", "< 1"
  spec.add_dependency "resolv", ">= 0.7.2", "< 1"
  spec.add_dependency "uri", ">= 1.0.4", "< 2"
  spec.add_dependency "zlib", ">= 3.2.3", "< 4"

  # Official Stagehand Ruby SDK (REST client). Loaded lazily by the Stagehand backend
  # so requiring the Gem never reads SDK environment variables or starts anything.
  spec.add_dependency "stagehand", "~> 3.21.0"
end
