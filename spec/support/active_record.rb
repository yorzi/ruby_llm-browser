# frozen_string_literal: true

require "ruby_llm/browser/rails"
require "logger"

# The Rails adapter specs run against a real (in-memory) SQLite database so the store's
# locking, unique indexes and fencing are exercised rather than stubbed.
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = Logger.new(IO::NULL)
ActiveJob::Base.logger = Logger.new(IO::NULL)
ActiveJob::Base.queue_adapter = :test

RubyLLM::Browser::Rails::Schema.create!

module BrowserSpecSupport
  # Helpers for the durable Rails adapter specs.
  module RailsHelpers
    def rails_store = RubyLLM::Browser::Rails.operation_store
    def rails_approval_store = RubyLLM::Browser::Rails.approval_store

    def build_operation(id: nil, actor_id: "actor-1", run_id: "run-1", state: :reserved,
                        budget: nil, session_id: nil, idempotency_key: nil, fence: 0, now: nil)
      time = now || fixed_time
      RubyLLM::Browser::Operation.new(
        id: id || RubyLLM::Browser::Operation.generate_id,
        actor_id: actor_id, run_id: run_id,
        budget: budget || RubyLLM::Browser::Budget.new,
        state: state, session_id: session_id, idempotency_key: idempotency_key,
        fence: fence, created_at: time, updated_at: time
      )
    end
  end
end

RSpec.configure do |config|
  config.include BrowserSpecSupport::RailsHelpers

  config.before do
    connection = ActiveRecord::Base.connection
    connection.execute("DELETE FROM ruby_llm_browser_operations")
    connection.execute("DELETE FROM ruby_llm_browser_approvals")
    RubyLLM::Browser::Rails.reset!
    RubyLLM::Browser::Rails.clock = -> { fixed_time }
    if defined?(RubyLLM::Browser::Rails::OperationJob)
      RubyLLM::Browser::Rails::OperationJob.context_factory = nil
      RubyLLM::Browser::Rails::OperationJob.operation_store = nil
    end
    adapter = ActiveJob::Base.queue_adapter
    adapter.enqueued_jobs.clear if adapter.respond_to?(:enqueued_jobs)
  end
end
