# frozen_string_literal: true

require_relative "lib/ruby_llm/browser/version"

Gem::Specification.new do |spec|
  spec.name = "ruby_llm-browser"
  spec.version = RubyLLM::Browser::VERSION
  spec.authors = [ "Andy Wang" ]
  spec.email = [ "wangyaodi@gmail.com" ]

  spec.summary = "Offline, policy-bound browser Inspect and Extract tools for RubyLLM."
  spec.description = <<~DESCRIPTION
    An unofficial community extension for RubyLLM. It adds policy-bound, read-only
    browser Inspect and Extract tools with an offline FakeBackend. The Stagehand Ruby SDK
    adapter is present but unsupported for live operations until provider egress and
    cleanup are qualified. The first release also includes
    explicit URL/SSRF policy, bounded and sanitized results with provenance, durable
    operation and session lifecycle bookkeeping, budgets, offline Act simulation, and an
    optional Rails 8 / Active Job adapter. The full live Act protocol is deferred to a
    later version. The Gem core works in plain
    Ruby without Rails.
  DESCRIPTION

  spec.homepage = "https://github.com/yorzi/ruby_llm-browser"
  spec.license = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.2")

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  package_files = Dir.glob("{lib,docs,examples}/**/*").select { |file| File.file?(file) }
  package_files.reject! do |file|
    file.start_with?("docs/_site/", "docs/vendor/", "docs/.bundle/", "docs/.jekyll-cache/", "docs/evidence/") ||
      %w[docs/Gemfile docs/Gemfile.lock docs/_site.ruby-llm-browser-generated].include?(file)
  end
  spec.files = package_files +
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
