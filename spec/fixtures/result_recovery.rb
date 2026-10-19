# frozen_string_literal: true

require_relative "../../examples/rails_results"

mode, database, queue_file = ARGV
host = BrowserResultsExample
adapter = RubyLLM::Browser::Rails
host.connect(database)

case mode
when "prepare"
  ActiveJob::Base.queue_adapter = host::FileQueue.new(queue_file)
  adapter::OperationJob.enqueue(actor_id: "actor", run_id: "run", kind: :extract,
                                url: "https://docs.example.com/", schema: host::SCHEMA,
                                budget: RubyLLM::Browser::Budget.new)
when "before-write", "after-write", "crash"
  backend = RubyLLM::Browser::FakeBackend.new
  host.configure(backend: backend)
  persist = adapter.result_delivery
  adapter.result_delivery = lambda do |operation:, result:|
    Process.kill("KILL", Process.pid) if mode == "crash"
    persist.call(operation: operation, result: result) if mode == "after-write"
    raise "storage unavailable password=private-secret"
  end
  begin
    ActiveJob::Base.execute(JSON.parse(File.read(queue_file)))
    raise "delivery failure was hidden"
  rescue RubyLLM::Browser::Rails::ResultDeliveryError => error
    raise "unsafe cause" if error.cause || error.message.include?("private-secret")
    raise "changed session state" unless adapter.operation_store.fetch!(error.operation.id).state == :closed
    2.times { persist.call(operation: error.operation, result: error.result) }
    # Even queue redelivery after a host delivery failure cannot start again.
    ActiveJob::Base.execute(JSON.parse(File.read(queue_file)))
    raise "repeated browser work" unless backend.call_count(:start) == 1 && backend.call_count(:end_session) == 1
    puts "DELIVERY_ONLY_RECOVERY_PASS"
  end
when "read"
  record = host::ResultRecord.first!
  operation = adapter.operation_store.fetch!(record.operation_id)
  payload = host.read_result(operation_id: operation.id, actor_id: "actor", run_id: "run")
  raise "lost result" unless payload.fetch("data") == { "title" => "Example" }
  # A conflicting body and a conflicting scope must both preserve the first write.
  [ [ operation, payload.merge("data" => { "title" => "changed" }) ],
    [ RubyLLM::Browser::Operation.new(**operation.to_h.merge(actor_id: "other")), payload ] ].each do |candidate, body|
    begin
      host.store_result(operation: candidate, payload: body)
      raise "conflicting overwrite accepted"
    rescue RubyLLM::Browser::InvalidInput
      # Expected conflict, with the original row intact.
    end
  end
  raise "duplicate rows" unless host::ResultRecord.count == 1
  raise "original changed" unless host.read_result(operation_id: operation.id, actor_id: "actor", run_id: "run") == payload
  puts "DURABLE_RECOVERY_PASS"
when "lost-result"
  backend = RubyLLM::Browser::FakeBackend.new
  host.configure(backend: backend)
  ActiveJob::Base.execute(JSON.parse(File.read(queue_file)))
  raise "repeated browser work" unless backend.call_count(:start).zero?
  raise "invented a result" unless host::ResultRecord.count.zero?
  raise "lost closed operation" unless adapter::OperationRecord.first!.state == "closed"
  puts "CRASH_GAP_NO_REPLAY_PASS"
else
  raise "unknown fixture mode"
end
