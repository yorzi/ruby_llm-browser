# frozen_string_literal: true

# Optional Rails 8 / ActiveRecord / Active Job adapter for RubyLLM::Browser.
#
#   # config/initializers/ruby_llm_browser.rb
#   require "ruby_llm/browser/rails"
#
#   RubyLLM::Browser::Rails.context_factory = lambda do |actor_id:, run_id:|
#     RubyLLM::Browser::Context.new(
#       actor_id: actor_id, run_id: run_id, backend: qualified_backend,
#       source_policy: host_policy,
#       operation_store: RubyLLM::Browser::Rails.operation_store
#     )
#   end
#
# This file is *not* loaded by `require "ruby_llm/browser"`. The Gem core stays
# Rails-free; only hosts that opt in load ActiveRecord and Active Job.
require "ruby_llm/browser"

require "json"
require "active_record"
require "active_job"

require_relative "rails/schema"
require_relative "rails/operation_record"
require_relative "rails/approval_record"
require_relative "rails/active_record_operation_store"
require_relative "rails/active_record_approval_store"

module RubyLLM
  module Browser
    # Durable, multi-worker adapter for hosts that run Rails (or plain ActiveRecord +
    # Active Job). It provides an ActiveRecord operation/approval store, a scoped
    # Active Job, and a cleanup reaper. It never guesses provider truth and never starts
    # a session the core would refuse.
    module Rails
      class << self
        # ->(actor_id:, run_id:) { RubyLLM::Browser::Context }, supplied by the host.
        attr_accessor :context_factory

        # Returns the current UTC time used by the adapter.
        def clock
          @clock ||= -> { Time.now.utc }
        end
        attr_writer :clock

        # The Active Job queue name. Defaults to `:default`.
        def job_queue
          @job_queue || :default
        end
        attr_writer :job_queue

        # Durable operation store. Defaults to an {ActiveRecordOperationStore}.
        def operation_store
          @operation_store ||= ActiveRecordOperationStore.new
        end
        attr_writer :operation_store

        # Durable approval store. Defaults to an {ActiveRecordApprovalStore}.
        def approval_store
          @approval_store ||= ActiveRecordApprovalStore.new
        end
        attr_writer :approval_store

        # Restores process defaults. Primarily a test helper.
        def reset!
          @context_factory = nil
          @clock = nil
          @job_queue = nil
          @operation_store = nil
          @approval_store = nil
        end
      end
    end
  end
end
