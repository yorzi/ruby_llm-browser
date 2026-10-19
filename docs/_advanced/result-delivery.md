---
layout: default
title: Rails Result Delivery
nav_order: 2
description: Persist sanitized background results in your application and recover delivery separately from browser cleanup.
---

# {{ page.title }}

{{ page.description }}

After reading this guide, you will know:

- How to receive a background operation's bounded result.
- How to store and authorize results in your application.
- How to recover delivery without repeating browser work.

## Persist a Result

Configure the optional Rails adapter and its context factory first. See
[Rails jobs and recovery]({% link _advanced/rails-integration.md %}). Register a trusted
callback in your initializer:

```ruby
RubyLLM::Browser::Rails.result_delivery = lambda do |operation:, result:|
  # Your host service persists result.to_h with operation.id, actor_id and run_id.
  BrowserResults.persist(operation: operation, payload: result.to_h)
end
```

`BrowserResults` is your application service. It is not a gem class. The callback
receives an immutable `Operation` snapshot and the core's sanitized, bounded `Result`.
Persist `result.to_h` or `result.to_json`, rather than the operation object, which
contains a provider session ID for trusted bookkeeping.

The callback runs synchronously in the worker after the engine attempts cleanup and
before the job returns. It receives successful, truncated, error, unknown, and
cleanup-pending results. Preflight exceptions have no `Result` and do not invoke it.
Cancellation or a changed fence detected after execution suppresses delivery. A
missing, already started, or terminal operation does not invoke it either.

The default is `nil`, which preserves the existing job return behavior. Setting the
hook to a non-callable value raises `InvalidInput`. Callback return values are ignored;
raise an exception if persistence fails.

## Keep Storage and Access in the Host

Use a unique operation ID for idempotent writes. Repeating a write of the same result
should succeed; reject a conflicting body or actor/run identity. Retrieve with the
authenticated actor and run in the database query. Never use model-supplied actor IDs
as authorization. Recheck host revocation and retention rules when serving a result.

The gem creates no result table and adds no migrations. Keep results in your host's
database or durable storage. Do not rely on an Active Job return value or in-memory
callback state after a worker exits.

An `ok` extraction passed the pinned schema before redaction and bounding. A truncated
result can contain a preview instead of the original schema shape. Treat all page
content as untrusted. Store failures too, without interpreting `cleanup_pending` or
`unknown` as success. A stored result describes that attempt; a later reaper changes
session state, not the historical result body.

## Recover Delivery Separately

If the callback raises, the job raises `RubyLLM::Browser::Rails::ResultDeliveryError`
with code `RESULT_DELIVERY_FAILED`. The original callback exception is not chained,
so automatic job logs cannot print its potentially sensitive message. The error
exposes `operation` and `result` to trusted, in-process host recovery code:

```ruby
# Inside host code that catches ResultDeliveryError while these objects still exist:
RubyLLM::Browser::Rails.result_delivery.call(
  operation: error.operation, result: error.result
)
```

This retries only your callback. Reauthorize recovery in the host. Keep external side
effects idempotent and persist the result before sending notifications. For durable
notification retries, write the result and a host outbox entry in one transaction.
An exception object does not survive worker exit as durable result storage.

A failed callback does not change the operation's session state or error code. Queue
redelivery of `OperationJob` does not repeat a started browser operation and does not
redeliver its result. Keep delivery failures visible in your job monitoring; retrying
the browser job is not a result-recovery mechanism.

There is no atomic transaction across provider execution, operation bookkeeping, and
host persistence. A process crash after execution but before persistence can lose the
result. The hook offers one automatic delivery attempt, not guaranteed or exactly-once
delivery. If host storage is unavailable, a recovery handler must save the retained
result to a separate durable destination before it exits. Never recover a lost result
by replaying an uncertain browser operation automatically.

Cancellation can race after the worker's final check. If your host forbids storing a
result after revocation, enforce that rule in the persistence transaction as well as
at read time. A callback failure must not clear cancellation, pending cleanup, or quota.

## Next Steps

Read [the API reference]({% link _reference/api-and-configuration.md %}) for result
fields and [Rails jobs and recovery]({% link _advanced/rails-integration.md %}) for
cancellation and reaper behavior.
