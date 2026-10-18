---
layout: default
title: Running work in Rails
nav_order: 1
description: Run durable inspect and extract operations with the Rails 8 adapter.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* Which framework versions and components the adapter expects.
* How to install its tables.
* What the host must own in background jobs and cleanup.

## Install the Adapter

The adapter is optional. Add Rails 8 Active Record and Active Job to the host application,
then require the Rails entry point and install its migration:

```ruby
require "ruby_llm/browser/rails"
```

```sh
bin/rails generate ruby_llm:browser:install
bin/rails db:migrate
```

The generator creates durable operation and approval tables plus per-actor reservation
locks. The jobs accept `inspect` and `extract`; Act is not available in background jobs.

## Keep Authorization in the Host

The context factory runs in the worker and must reload trusted records, recheck actor and
run authorization, and use the same operation store and budget limits as the reservation.
Never put provider credentials or authorization decisions in model arguments or job
payloads. Protect queue storage because URLs, instructions, and schemas are persisted.

## Schedule Recovery

Run `RubyLLM::Browser::Rails::Reaper` on a separate schedule. Worker cleanup alone cannot
recover sessions left by a killed process. Do not free quota for an unknown or pending
session based only on elapsed time. The job does not durably store result bodies, so the
host must implement authorized result storage and delivery if it needs them.

SQLite concurrency is exercised locally. PostgreSQL still needs separate qualification,
and MySQL is not supported by the adapter's locking contract. See the [full Rails guide]({% link RAILS.md %}) for a context factory, enqueueing, status access, migration recovery, and reaper details.

## Next Steps

* [Bounding operation work]({% link _core_features/operation-lifecycle.md %}) - understand budgets and state transitions.
* [Qualifying a live backend]({% link _advanced/live-backend-qualification.md %}) - review provider requirements.
