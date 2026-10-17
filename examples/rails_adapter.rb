#!/usr/bin/env ruby
# frozen_string_literal: true

# Offline demo of the Rails adapter on in-memory SQLite: no network, no API key.
#
#   bundle exec ruby examples/rails_adapter.rb
require "ruby_llm/browser/rails"
require "active_record"

class DemoResolver
  def getaddresses(_host) = [ "93.184.216.34" ]
end

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
RubyLLM::Browser::Rails::Schema.create!

# `:inline` runs the queued job immediately so the demo is synchronous and deterministic.
ActiveJob::Base.queue_adapter = :inline
ActiveJob::Base.logger = Logger.new(IO::NULL)

policy = RubyLLM::Browser::Policy.new(
  allowed_hosts: [ "docs.example.com" ], resolver: DemoResolver.new
)
budget = RubyLLM::Browser::Budget.new(max_seconds: 30, max_steps: 6)

RubyLLM::Browser::Rails.context_factory = lambda do |actor_id:, run_id:|
  RubyLLM::Browser::Context.new(
    actor_id: actor_id, run_id: run_id, source_policy: policy,
    backend: RubyLLM::Browser::FakeBackend.new,
    operation_store: RubyLLM::Browser::Rails.operation_store,
    budget: budget
  )
end

operation = RubyLLM::Browser::Rails::OperationJob.enqueue(
  actor_id: "demo-actor", run_id: "demo-run", kind: :inspect,
  url: "https://docs.example.com/", budget: budget, idempotency_key: "demo-1"
)

puts "operation #{operation.id} is #{RubyLLM::Browser::Rails.operation_store.fetch(operation.id).state}"

# A duplicate delivery attaches to the same durable operation.
again = RubyLLM::Browser::Rails::OperationJob.enqueue(
  actor_id: "demo-actor", run_id: "demo-run", kind: :inspect,
  url: "https://docs.example.com/", budget: budget, idempotency_key: "demo-1"
)
puts "duplicate attached: #{again.id == operation.id}"
