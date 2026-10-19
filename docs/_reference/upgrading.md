---
layout: default
title: Upgrading
nav_order: 2
description: Upgrade from 0.1.0 while preserving tool registration, diagnostics, and operation data.
---

# {{ page.title }}

{{ page.description }}

After reading this guide, you will know:

- How to update an application from 0.1.0.
- Which tool and diagnostic contracts remain compatible.
- How to preserve data from earlier development snapshots.

## Upgrade from 0.2.0

The 0.3 development candidate adds no gem-managed database migration. Preserve all
operation, approval, and actor-lock rows. Do not rerun the install generator on an
existing installation. Result storage belongs to your application.

`Rails.result_delivery` defaults to `nil`. Existing job return values remain supported.
A worker fenced during browser execution now returns `:fenced_out` and cannot deliver
its stale result. Cancelled work never invokes the delivery hook, including while
cleanup remains pending. To opt in, follow
[Rails Result Delivery]({% link _advanced/result-delivery.md %}).

A callback failure raises `Rails::ResultDeliveryError`. Queue retries do not redeliver
a result. Configure host persistence and recovery before enabling the callback; the
retained error object is not durable storage. Stagehand remains unsupported.

## Upgrade from 0.1.0

Update your Gemfile and bundle:

```ruby
gem "ruby_llm-browser", "~> {{ site.version }}"
```

```sh
bundle update ruby_llm-browser
```

There is no database migration or new runtime dependency. Keep existing operation and
approval records. The individual Inspect and Extract constructors remain supported.
You can optionally replace their registration with:

```ruby
chat.with_tools(*RubyLLM::Browser.tools(context: context, schema: schema))
```

The host still supplies the context and extraction schema. The factory never adds Act.

## Read Doctor Reports by Name

Doctor adds `mode` while retaining `ok`, `summary`, and `checks`. Check names now depend
on the backend. Do not require Stagehand or credential checks in every report, and do
not rely on check order. FakeBackend diagnostics skip provider environment and SDK
checks. Stagehand still reports a failure; `mode: :live` does not enable it.

Read [Checking Configuration]({% link _core_features/diagnostics.md %}) for the report
fields. No live browser provider is supported by this release.

## Earlier Development Snapshots

If you used an earlier development Rails generator, preserve operation data and follow
the additive migration instructions in the
[Rails guide]({% link _advanced/rails-integration.md %}). Drain workers during migration;
do not reuse idempotency keys for legacy rows without request digests.

For the previous version's instructions, read the
[0.1.0 upgrading guide](https://github.com/yorzi/ruby_llm-browser/blob/v0.1.0/docs/_reference/upgrading.md).

## Next Steps

- Read [What's New in 0.2]({% link _getting_started/whats-new-in-0-2.md %}).
- Review [release history]({% link _reference/release-history.md %}) and
  [live-backend qualification]({% link _advanced/live-backend-qualification.md %}).
