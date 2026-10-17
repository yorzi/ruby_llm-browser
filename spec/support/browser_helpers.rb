# frozen_string_literal: true

module BrowserSpecSupport
  # Builders for the trusted host objects specs need: policy, context, approvals.
  module Helpers
    # A public, non-reserved IPv4 address used for every fake DNS answer.
    PUBLIC_IP = "93.184.216.34"

    # The deterministic clock used unless a spec overrides it.
    def fixed_time = Time.utc(2026, 10, 17, 12, 0, 0)

    def build_resolver(hosts)
      BrowserSpecSupport::FakeResolver.new(
        Array(hosts).to_h { |host| [ host, [ PUBLIC_IP ] ] }
      )
    end

    def build_policy(allowed_hosts: [ "docs.example.com" ], resolver: nil, **options)
      hosts = Array(allowed_hosts)
      RubyLLM::Browser::Policy.new(
        allowed_hosts: hosts,
        resolver: resolver || build_resolver(hosts),
        **options
      )
    end

    def build_context(backend: nil, policy: nil, allowed_hosts: [ "docs.example.com" ],
                      operation_store: nil, approval_store: nil, budget: nil,
                      actor_id: "actor-1", run_id: "run-1", clock: nil, consent: nil)
      backend ||= RubyLLM::Browser::FakeBackend.new
      RubyLLM::Browser::Context.new(
        actor_id: actor_id, run_id: run_id, backend: backend,
        source_policy: policy || build_policy(allowed_hosts: allowed_hosts),
        operation_store: operation_store || RubyLLM::Browser::InMemoryOperationStore.new,
        approval_store: approval_store, budget: budget,
        clock: clock || -> { fixed_time }, consent: consent
      )
    end

    # Builds and stores a fresh approval bound to the given details.
    def build_approval(store, context: nil, url:, action:, ttl: 300, now: nil,
                       page_revision: nil, **overrides)
      context ||= @context
      time = now || fixed_time
      approval = RubyLLM::Browser::Approval.for_action(
        actor_id: context.actor_id, run_id: context.run_id, url: url, action: action,
        ttl: ttl, now: time, page_revision: page_revision, **overrides
      )
      store.issue(approval)
    end
  end
end

RSpec.configure do |config|
  config.include BrowserSpecSupport::Helpers
end
