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
    operation and session lifecycle bookkeeping, budgets, an opt-in human-approved Act
    tool, and an optional Rails 8 / Active Job adapter. The Gem core works in plain
    Ruby without Rails.
  DESCRIPTION

  spec.homepage = "https://github.com/yorzi/ruby_llm-browser"
  spec.license = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.2")

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.glob("lib/**/*").select { |file| File.file?(file) } +
               %w[README.md CHANGELOG.md LICENSE.txt NOTICE.md SECURITY.md]
  spec.require_paths = [ "lib" ]

  # RubyLLM owns the Tool and chat execution loop; this Gem only adds browser tools.
  spec.add_dependency "ruby_llm", ">= 2.0", "< 3"

  # Official Stagehand Ruby SDK (REST client). Loaded lazily by the Stagehand backend
  # so requiring the Gem never reads SDK environment variables or starts anything.
  spec.add_dependency "stagehand", "~> 3.21"
end
