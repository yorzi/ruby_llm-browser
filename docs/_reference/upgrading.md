---
layout: default
title: Upgrading
nav_order: 2
description: Upgrade from 0.2.0 while preserving operation data and configuring optional Rails result delivery.
---

# {{ page.title }}

{{ page.description }}

After reading this guide, you will know:

- How to update an application from 0.2.0.
- How to preserve existing data and enable result delivery.
- Which result and worker behaviors change.

## Upgrade from 0.2.0

Update your Gemfile and bundle:

```ruby
gem "ruby_llm-browser", "~> {{ site.version }}"
```

```sh
bundle update ruby_llm-browser
```

This release adds no gem-managed database migration or runtime dependency. Preserve all
operation, approval, and actor-lock rows. Do not rerun the install generator on an
existing installation. Result storage belongs to your application.

## Enable Result Delivery When Needed

`RubyLLM::Browser::Rails.result_delivery` defaults to `nil`. Existing job return values
remain supported. To retain results after a worker exits, follow
[Rails Result Delivery]({% link _advanced/result-delivery.md %}). Configure persistence,
authorized reads, idempotent writes, and recovery before enabling the callback.

A callback failure raises `Rails::ResultDeliveryError`. Queue retries do not redeliver
a result. The error retains the result only in process; it is not durable storage.
Recover delivery separately from browser execution. A crash before host persistence
can still lose the result, so do not treat this hook as guaranteed delivery.

## Account for Immutable Results and Fenced Workers

`Result` now also copies and freezes operation ID, error code and error message strings,
consistent with its other fields. Mutating these attributes raises `FrozenError`;
duplicate a string before changing it in host code. Caller-owned inputs stay mutable.

A worker fenced during browser execution now returns `:fenced_out` and cannot deliver
its stale result. Cancelled work never invokes the delivery hook, including while
cleanup remains pending. Delivery failures do not change the session state or free
quota. Stagehand and live Act remain unsupported.

## Earlier Versions

For upgrades from 0.1.0 and earlier development snapshots, first follow the
[0.2.0 upgrading guide](https://github.com/yorzi/ruby_llm-browser/blob/v0.2.0/docs/_reference/upgrading.md).
Preserve operation data and use additive migrations where required.

## Next Steps

- Read [What's New in 0.3]({% link _getting_started/whats-new-in-0-3.md %}).
- Review [release history]({% link _reference/release-history.md %}) and
  [live-backend qualification]({% link _advanced/live-backend-qualification.md %}).
