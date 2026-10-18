# frozen_string_literal: true

require "ruby_llm/browser/rails"

class OfflineWorkerResolver
  def getaddresses(_host) = [ "93.184.216.34" ]
end

class KilledWorkerBackend < RubyLLM::Browser::FakeBackend
  def observe(*)
    Process.kill("KILL", Process.pid)
  end
end

mode, database = ARGV
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: database)
RubyLLM::Browser::Rails::Schema.create!
store = RubyLLM::Browser::Rails.operation_store

if mode == "crash"
  context = RubyLLM::Browser::Context.new(
    actor_id: "crashed-actor", run_id: "crashed-run", operation_store: store,
    backend: KilledWorkerBackend.new,
    source_policy: RubyLLM::Browser::Policy.new(allowed_hosts: [ "docs.example.com" ], resolver: OfflineWorkerResolver.new)
  )
  RubyLLM::Browser::Engine.new(context: context).inspect(url: "https://docs.example.com/")
else
  before = store.open_operations.fetch(0)
  raise "lost persisted session" unless before.state == :active && before.session_id == "fake-session-1"

  backend = RubyLLM::Browser::FakeBackend.new(reconcile_state: :unknown)
  report = RubyLLM::Browser::Rails::Reaper.new(backend: backend).sweep(now: Time.now.utc + 300)
  raise "did not close" unless report[:closed] == 1 && backend.call_count(:end_session) == 1
  raise "reservation was not released" unless store.open_operations.empty?

  puts "PASS killed worker recovered from persisted session"
end
