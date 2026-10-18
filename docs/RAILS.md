---
layout: default
title: Rails Jobs and Recovery
description: Run bounded read-only operations with durable state and independently scheduled cleanup.
---

# Rails jobs and recovery

Run bounded read-only operations with durable state and independently scheduled cleanup.

After reading this guide, you will know:

- How to install the adapter's tables.
- How to build a freshly authorized job context with matching budgets.
- How to inspect status, cancel work, and recover orphaned sessions.

## Installing the adapter

Your application supplies Rails 8, Active Record, Active Job, and a database adapter.
They are not runtime dependencies of the plain-Ruby gem.

```ruby
require "ruby_llm/browser/rails"
```

```bash
bin/rails generate ruby_llm:browser:install
bin/rails db:migrate
```

The generator creates operations, approvals, and per-actor reservation-lock tables.
SQLite and PostgreSQL are accepted by the store, but only SQLite concurrency is tested
locally. MySQL is not supported by this adapter's partial indexes/locking contract.
Use a database timeout appropriate to your workload. Database lock failures fail closed;
they must not be handled by retrying a browser call with a new operation ID.

`Schema.create!` is for disposable fixtures, not production migrations or schema upgrades.
The [offline Rails example](https://github.com/yorzi/ruby_llm-browser/blob/main/examples/rails_adapter.rb) requires no full Rails app.

## Configuring the trusted context factory

```ruby
# config/initializers/ruby_llm_browser.rb
require "ruby_llm/browser/rails"

browser_budget = RubyLLM::Browser::Budget.new(max_seconds: 30, max_steps: 6)
RubyLLM::Browser::Rails.context_factory = lambda do |actor_id:, run_id:|
  # Resolve authenticated host records and recheck authorization, consent and revocation.
  # Build policy/backend from those records, never from job or model-supplied credentials.
  RubyLLM::Browser::Context.new(
    actor_id: actor_id, run_id: run_id,
    backend: qualified_backend, source_policy: policy,
    operation_store: RubyLLM::Browser::Rails.operation_store,
    budget: browser_budget
  )
end
```

`qualified_backend` and `policy` above are host objects, not global APIs supplied by the
gem. The factory must use the **same operation-store instance and budget limits** as
the queued reservation. Construct different budgets per run only from trusted records
that the factory can retrieve again. An optional approval store does not enable Act in
jobs; `OperationJob` accepts only `inspect` and `extract`.

## Enqueuing a read-only operation

```ruby
operation = RubyLLM::Browser::Rails::OperationJob.enqueue(
  actor_id: current_user.id.to_s, run_id: research_run.id.to_s,
  kind: :inspect, url: "https://docs.example.com/",
  budget: browser_budget, idempotency_key: "research-#{research_run.id}"
)
```

For extraction, pass `kind: :extract` and a host-pinned JSON `schema:`. Optional
`instruction:` and `max_bytes:` have the same meaning as on the tools.

One actor/run/key identifies one exact payload and budget. A changed payload using the
same key is rejected. Repeated enqueue calls may add duplicate queue deliveries, but
they attach to the same durable operation. Starting is atomically claimed once. A job
that sees a started, unknown, pending-cleanup, or terminal operation cannot start it
again. No automatic browser retry is configured.

Reservation and queue insertion are separate transactions. If enqueueing fails, retain
the returned operation identity when available and use the same idempotency key after
investigation. Schedule the reaper to reclaim expired reservations that never started.

Configure `RubyLLM::Browser::Rails.job_queue = :browser` if you need a separate queue.
Jobs suppress argument logging, but queues still persist URLs, instructions and schemas.
Protect queue access, storage, retention and encryption in the host application.

## Reading status and progress

```ruby
store = RubyLLM::Browser::Rails.operation_store
operation = store.fetch!(operation_id)
# Authorize this read against the authenticated actor/run before returning anything.
summary = operation.summary
```

`summary` omits provider session IDs and budget internals. It reports state, steps,
bytes, fence, timestamps, error code and cancellation flag. It is coarse progress,
not a percentage-complete promise. No result body is durably stored by the job; the
host must explicitly implement authorized result storage/delivery if needed. Do not
rely on an Active Job return value after asynchronous execution.

The stores are trusted server APIs, not tenant-safe controllers. They expose unscoped
fetch/sweep methods for workers; never expose them directly to model arguments or HTTP.
Tool progress callbacks are feature-detected on RubyLLM 2.1+, and contain no raw URL.

## Cancelling and reaping

```ruby
store.cancel(operation_id, actor_id: current_user.id.to_s,
             run_id: research_run.id.to_s, now: Time.now.utc)
RubyLLM::Browser::Rails::Reaper.new(backend: qualified_backend).sweep
```

Cancellation of a never-started reservation is terminal immediately. Otherwise it sets
`cancel_requested`, fences stale workers, and remains `cleanup_pending` with quota held.
It cannot undo an in-flight provider request. A returned session ID is persisted even
if cancellation raced with session creation.

Run a reaper regularly in an independent scheduler, not only in the operation worker's
ensure block. A reaper fences workers **before** reconciliation/cleanup, tries to end
known sessions even when provider reconciliation is unavailable, and reports `failed`
rather than claiming a database write succeeded. `ttl_seconds:` is an optional positive
idle threshold, not proof that the provider's billable session has expired.

Stagehand exposes no correlation endpoint here. An unknown start without a session ID
remains unknown and holds quota until the host supplies provider-confirmed evidence.
Alert on unknown/pending/failed entries. Never free quota just because enough local time
passed. An unknown action outcome remains in the result/error code even if session
cleanup succeeds; do not replay it.

One reaper/backend instance must cover only operations belonging to that provider
configuration. The current table has no backend credential-configuration binding.
Multi-provider/multi-credential deployments need a host-scoped store or a future schema
extension before a global sweep is safe.

## Upgrading an earlier development snapshot

Nothing has been publicly released. If you already ran the earlier generator, preserve
your data and add an explicit migration for these new fields instead of rerunning
`create_table` or dropping the database:

```ruby
class HardenBrowserBookkeeping < ActiveRecord::Migration[8.1]
  def change
    create_table :ruby_llm_browser_actors, id: :string do |t|
      t.integer :sequence, null: false, default: 0
    end
    add_column :ruby_llm_browser_operations, :cancel_requested, :boolean, default: false, null: false
    add_column :ruby_llm_browser_operations, :request_digest, :string
  end
end
```

Adapt this migration if any additions already exist. Drain workers during the upgrade.
Legacy rows without request digests are not payload-bound, so do not reuse their
idempotency keys for new work. Inspect earlier terminal cancellations for sessions that
may not have been confirmed closed before reclaiming them.

## Next steps

- Review [the API]({% link API.md %}) for result interpretation and budget semantics.
- Review [release blockers]({% link RELEASE_AUDIT.md %}) before production deployment.
