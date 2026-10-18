---
layout: default
title: Bounding operation work
nav_order: 3
description: Limit browser work by time, steps, retained bytes, and actor concurrency.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* Which limits a `Budget` applies to an operation.
* How operation states prevent unsafe retries.
* When a durable store and independent reaper are required.

## Set a Budget

Each context receives a `Budget`. Defaults are 60 seconds, 12 provider steps, 262,144
retained bytes, and one concurrent operation per actor. A smaller budget can cap one
workflow:

```ruby
require "ruby_llm/browser"

budget = RubyLLM::Browser::Budget.new(
  max_seconds: 30, max_steps: 6, max_bytes: 32_768,
  max_concurrent: 1, max_cost_usd: 0.25
)
puts budget.to_h
```

Steps count navigation, observation, extraction, and action calls. Byte limits count
retained sanitized result data, not all bytes the remote browser receives. The optional
`max_cost_usd` value is advisory metadata. It is not a provider billing cap.

## Track an Operation

An operation is claimed before it starts. The Engine records state changes, step and byte
usage, session identity, and cleanup status. A duplicate start cannot run the same
operation again. SDK retries are disabled, and unknown outcomes are not automatically
replayed.

The in-memory store is useful for examples or a single process. It does not survive a
restart or coordinate workers. Use the Rails adapter or implement a durable
`OperationStore` when operations can outlive a process. Keep `unknown` and
`cleanup_pending` operations visible and retain their quota until closure is confirmed.

## Reap Independently

Cancellation fences workers but cannot undo a request already in flight. A reaper should
run on an independent schedule so it can reconcile and close known sessions after a job
worker exits. Provider time passing is not proof that a session closed or stopped
incurring costs.

The Rails adapter and its scheduling requirements are described in [Running work in Rails]({% link _advanced/rails-integration.md %}). Result limits and status meanings are in the [API reference]({% link _reference/api-reference.md %}).

## Next Steps

* [Running work in Rails]({% link _advanced/rails-integration.md %}) - persist operations across workers.
* [API and configuration reference]({% link _reference/api-reference.md %}) - inspect status fields and defaults.
