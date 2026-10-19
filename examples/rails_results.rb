# frozen_string_literal: true

# A host-owned result table and a single-job file queue, using only FakeBackend.
# This disposable demonstration is not a production queue, controller or migration.
require "ruby_llm/browser/rails"
require "logger"
require "open3"
require "tmpdir"

module BrowserResultsExample
  SCHEMA = { "type" => "object", "properties" => { "title" => { "type" => "string" } },
             "required" => [ "title" ], "additionalProperties" => false }.freeze
  RESOLVER = Object.new
  def RESOLVER.getaddresses(_host) = [ "93.184.216.34" ]

  class ResultRecord < ActiveRecord::Base
    self.table_name = "example_browser_results"
    self.primary_key = "operation_id"
  end

  class FileQueue
    def initialize(path) = @path = path
    def enqueue(job) = File.write(@path, JSON.generate(job.serialize))
    def enqueue_at(*) = raise(ArgumentError, "demo queue supports immediate jobs only")
  end

  module_function

  def connect(database)
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: database, timeout: 5000)
    ActiveRecord::Base.logger = Logger.new(IO::NULL)
    ActiveJob::Base.logger = Logger.new(IO::NULL)
    RubyLLM::Browser::Rails::Schema.create!
    connection = ActiveRecord::Base.connection
    return if connection.table_exists?(ResultRecord.table_name)

    connection.create_table(ResultRecord.table_name, id: false) do |table|
      table.string :operation_id, primary_key: true, null: false
      table.string :actor_id, null: false
      table.string :run_id, null: false
      table.text :body, null: false
      table.datetime :created_at, null: false
    end
  end

  def configure(backend: RubyLLM::Browser::FakeBackend.new)
    RubyLLM::Browser::Rails.context_factory = lambda do |actor_id:, run_id:|
      RubyLLM::Browser::Context.new(
        actor_id: actor_id, run_id: run_id, backend: backend,
        source_policy: RubyLLM::Browser::Policy.new(allowed_hosts: [ "docs.example.com" ], resolver: RESOLVER),
        operation_store: RubyLLM::Browser::Rails.operation_store
      )
    end
    RubyLLM::Browser::Rails.result_delivery = lambda do |operation:, result:|
      store_result(operation: operation, payload: result.to_h)
    end
  end

  # Trusted server API. The worker supplies identity, never a model or request body.
  def store_result(operation:, payload:)
    body = RubyLLM::Browser::Redactor.canonical_json(payload)
    ResultRecord.transaction do
      record = ResultRecord.create_or_find_by!(operation_id: operation.id) do |row|
        row.actor_id = operation.actor_id
        row.run_id = operation.run_id
        row.body = body
      end
      unless [ record.actor_id, record.run_id, record.body ] == [ operation.actor_id, operation.run_id, body ]
        raise RubyLLM::Browser::InvalidInput, "conflicting result delivery"
      end
    end
  end

  # In an HTTP host, derive actor/run from authenticated records and recheck access.
  # Use the same response for a missing result and an inaccessible result.
  def read_result(operation_id:, actor_id:, run_id:)
    record = ResultRecord.find_by(operation_id: operation_id, actor_id: actor_id, run_id: run_id)
    raise RubyLLM::Browser::NotAuthorized, "result unavailable" unless record

    JSON.parse(record.body)
  end

  def worker(database, queue_file)
    connect(database)
    backend = RubyLLM::Browser::FakeBackend.new
    configure(backend: backend)
    ActiveJob::Base.execute(JSON.parse(File.read(queue_file)))
    puts JSON.generate(starts: backend.call_count(:start), closes: backend.call_count(:end_session))
  end

  def run_demo
    Dir.mktmpdir("browser-results-") do |directory|
      database = File.join(directory, "host.sqlite3")
      queue_file = File.join(directory, "job.json")
      connect(database)
      ActiveJob::Base.queue_adapter = FileQueue.new(queue_file)
      operation = RubyLLM::Browser::Rails::OperationJob.enqueue(
        actor_id: "demo-actor", run_id: "demo-run", kind: :extract,
        url: "https://docs.example.com/", schema: SCHEMA,
        budget: RubyLLM::Browser::Budget.new, idempotency_key: "demo-result"
      )
      # capture3 waits for exit. Execute the serialized job twice in separate workers.
      [ 1, 0 ].each do |expected_starts|
        stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-I", File.expand_path("../lib", __dir__),
                                               __FILE__, "worker", database, queue_file)
        raise "worker failed: #{stderr}" unless status.success?
        unless JSON.parse(stdout) == { "starts" => expected_starts, "closes" => expected_starts }
          raise "unexpected browser dispatch"
        end
      end

      payload = read_result(operation_id: operation.id, actor_id: "demo-actor", run_id: "demo-run")
      raise "lost extraction" unless payload.fetch("data") == { "title" => "Example" } && payload.fetch("status") == "ok"
      raise "lost provenance" unless payload.fetch("locator").fetch("schema_digest") == RubyLLM::Browser::Redactor.digest(SCHEMA)
      puts "RESULT_AFTER_WORKER_EXIT_PASS"

      [ [ "other-actor", "demo-run" ], [ "demo-actor", "other-run" ] ].each do |actor, run|
        begin
          read_result(operation_id: operation.id, actor_id: actor, run_id: run)
          raise "cross-scope result leak"
        rescue RubyLLM::Browser::NotAuthorized
          # Expected refusal, including after the worker has exited.
        end
      end
      puts "SCOPED_READS_PASS"
      2.times { store_result(operation: operation, payload: payload) }
      raise "duplicate result rows" unless ResultRecord.count == 1
      puts "IDEMPOTENT_WRITE_PASS"
    ensure
      ActiveRecord::Base.connection_pool.disconnect!
    end
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV.first == "worker"
    BrowserResultsExample.worker(*ARGV.drop(1))
  else
    BrowserResultsExample.run_demo
  end
end
