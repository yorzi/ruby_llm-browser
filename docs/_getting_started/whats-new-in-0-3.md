---
layout: default
title: What's New in 0.3
redirect_from:
  - /whats-new/
nav_order: 4
description: Deliver Rails background results to host storage without repeating browser work on delivery failure.
---

# {{ page.title }}

{{ page.description }}

After reading this guide, you will know:

- How to persist the result of a background operation.
- Which delivery failures your application must recover.
- Which capabilities remain unsupported.

## Rails Result Delivery

This is an unreleased development candidate. Register a host callback to receive each
eligible job's sanitized `Result` after execution and cleanup:

```ruby
RubyLLM::Browser::Rails.result_delivery = lambda do |operation:, result:|
  BrowserResults.persist(operation: operation, payload: result.to_h)
end
```

Your application supplies `BrowserResults`, storage, access checks, retention, and
idempotent recovery. The gem adds no database tables or runtime dependencies. Read
[Rails Result Delivery]({% link _advanced/result-delivery.md %}) for the contract.

Run `bundle exec ruby examples/rails_results.rb` for a disposable SQLite host example.
It executes a serialized job in a separate process, waits for the worker to exit,
then verifies result retrieval, actor/run isolation, and idempotent persistence.

## Delivery Failure Is Separate from Cleanup

A callback failure raises `Rails::ResultDeliveryError` with the retained operation and
result. It does not change session state. A duplicate browser job does not rerun the
operation or redeliver the result. Recover host delivery using the retained result;
do not enqueue a new browser operation to recover persistence.

The hook cannot guarantee delivery across worker crashes. Stagehand and live Act remain
unsupported. Review [the roadmap]({% link _reference/roadmap.md %}) for live-backend
qualification and the remaining 1.0 requirements.
