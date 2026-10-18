# frozen_string_literal: true

# Run in a subprocess so a file-backed database and independent connections cannot
# contaminate the suite's in-memory fixture. Queues provide barriers, not sleeps.
require "ruby_llm/browser/rails"
require "tmpdir"

Dir.mktmpdir("browser-concurrency") do |directory|
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: File.join(directory, "store.sqlite3"),
                                         timeout: 10_000, pool: 8)
  RubyLLM::Browser::Rails::Schema.create!
  store = RubyLLM::Browser::Rails::ActiveRecordOperationStore.new
  now = Time.now.utc
  build = lambda do |id, actor, key = nil|
    RubyLLM::Browser::Operation.new(id: id, actor_id: actor, run_id: "run", idempotency_key: key,
                                    budget: RubyLLM::Browser::Budget.new, created_at: now)
  end
  race = lambda do |&block|
    ready = Queue.new
    release = Queue.new
    threads = 4.times.map do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          release.pop
          block.call(index)
        rescue RubyLLM::Browser::Error => e
          e.code
        end
      end
    end
    4.times { ready.pop }
    4.times { release << true }
    threads.map(&:value)
  end

  reservations = race.call { |index| store.reserve(build.call("op-#{index}", "quota")).id }
  raise "quota race: #{reservations}" unless reservations.count { |value| value.start_with?("op-") } == 1
  duplicates = race.call { |index| store.attach_or_reserve(build.call("dup-#{index}", "duplicate", "same-key")).id }
  raise "idempotency race: #{duplicates}" unless duplicates.uniq.length == 1
  original = store.reserve(build.call("claim-once", "claim"))
  claims = race.call { store.claim_start(original, now: now).state.to_s }
  raise "start race: #{claims}" unless claims.count("starting") == 1

  approvals = RubyLLM::Browser::Rails::ActiveRecordApprovalStore.new
  grant = RubyLLM::Browser::Approval.for_action(actor_id: "a", run_id: "r", url: "https://example.com/",
                                              action: {}, ttl: 60, now: now)
  approvals.issue(grant)
  consumed = race.call do
    approvals.consume_once(grant.id, actor_id: "a", run_id: "r", url: "https://example.com/",
                           action_digest: grant.action_digest, now: now).consumed? ? "consumed" : "bad"
  end
  raise "approval race: #{consumed}" unless consumed.count("consumed") == 1
  puts "PASS quota idempotency start approval"
end
