---
layout: default
title: API and Configuration
nav_order: 3
permalink: /api-and-configuration/
description: Configure trusted host objects and interpret bounded untrusted results.
---

# API and configuration

Configure trusted host objects and interpret bounded, untrusted results.

After reading this guide, you will know:

- How to register read-only tools.
- Which inputs belong to the host and which belong to the model.
- How to configure budgets, schemas, backends, and error handling.

## Creating a context

Use the complete offline example in [Getting Started]({% link _getting_started/getting-started.md %}). `Context.new` requires:

| Keyword | Type and meaning |
| --- | --- |
| `actor_id`, `run_id` | Nonempty strings from authenticated host records. Convert numeric database IDs with `to_s`. |
| `backend` | A `Backend` instance. Use `FakeBackend` for offline tests. |
| `source_policy` | A host-created `Policy`. |
| `operation_store` | An `OperationStore`; durable storage is required across restarts or workers. |
| `approval_store` | Optional `ApprovalStore`, needed only for experimental Act. |
| `budget` | Optional `Budget`; defaults listed below. |
| `clock` | Optional callable returning a UTC `Time`. |
| `logger` | Optional host logger. Do not enable raw provider or tool payload logging. |
| `consent` | Optional host consent record. The gem records its presence; it does not collect or authenticate consent. |
| `metadata` | Optional host metadata. Never supply credentials here. |

The host must reauthorize actor/run access when building a context, including background
jobs. Passing IDs alone is not authentication. The model must never choose a backend,
credential, schema, source allowlist, consent record, or budget.

## Registering tools

```ruby
chat.with_tools(*RubyLLM::Browser.tools(context: context, schema: schema))
```

`Browser.tools` returns fresh Inspect and Extract instances in that order, sharing
the supplied context. It never includes Act or dispatches an operation. You can also
construct either tool separately with `Inspect.new(context:)` and
`Extract.new(context:, schema:)`. Constructors reject missing host bindings; schema
contents are validated by policy when Extract runs, before a session starts.

Both tools expose `url`, optional `instruction`, and optional positive integer
`max_bytes`. `max_bytes` can only tighten the policy and operation ceilings.
`Extract` takes its schema in the constructor, not in model arguments.

`Inspect` returns **candidate interactions**, not a screenshot or arbitrary page dump.
Neither read-only tool dispatches candidates automatically. Pages may still run scripts
and initiate requests; read-only does not mean browsing has no external effects.

`Tool#execute` and RubyLLM `Tool#call` return a Hash. If you need a `Result` object, use:

```ruby
engine = RubyLLM::Browser::Engine.new(context: context)
result = engine.inspect(url: url)
result = engine.extract(url: url, schema: schema, instruction: "Find the title")
```

The optional `operation:` Engine keyword accepts a host-reserved operation with the
same actor/run and budget. Starting it is an atomic reserved-to-starting claim. It is
not a resume or retry API for active, unknown, or closed operations.

## Source policy

`Policy.new(allowed_hosts: [...])` accepts exact hosts and `*.example.com` subdomains.
A wildcard does not allow the bare domain. Defaults are HTTP/HTTPS and ports 80/443.
Keep `verify_dns: true`; `resolver:` is injectable for offline fixtures.

Other options are `allowed_schemes`, `allowed_ports`, `max_result_bytes` (65,536),
`max_schema_depth` (8), `max_schema_properties` (64 root properties), and
`max_schema_bytes` (16,384). Browser-side enforcement must also cover explicitly
approved asset origins, redirects, frames, popups, WebSockets, and subresources.

## Extraction schemas

Schemas must be bounded object JSON Schemas, passed as a Hash, JSON object string, or
an object/class supporting `to_json_schema`. Supported keywords are `type`,
`description`, `properties`, `required`, `items`, `enum`, `additionalProperties`,
`title`, `minimum`, `maximum`, `minLength`, `maxLength`, `minItems`, `maxItems`,
`format`, and `default`. Remote references and arbitrary schema extensions are refused.

Use `required` and `additionalProperties: false` when an exact shape matters. Provider
data must satisfy the schema before redaction or truncation. Invalid data returns
`PROVIDER_ERROR`; it is not returned as a successful extraction. A truncated preview
or redacted field need not retain the original schema's type. Always check the status.

## Results and errors

`Result` copies and freezes its strings and nested data. This includes operation ID,
error code and error message; changes to constructor inputs cannot alter a retained
result. Duplicate a returned string if host code needs to edit it.

`Result#to_h` contains symbol keys: `status`, `operation_id`, `final_url`,
`captured_at` (UTC ISO 8601), `locator`, `digest`, `truncated`, `data`, and optional
`error: { code:, message: }`. Locator/data objects use string keys. JSON encodes all
keys as strings. Credential-like query values are redacted in URL provenance.

Statuses are `ok`, `truncated`, `error`, `unknown`, and `cleanup_pending`.
`Result#ok?` accepts `ok` and `truncated`; it makes no factual verification claim.
`digest` is SHA-256 of canonical JSON of the returned, sanitized data. Very small byte
limits can produce an empty string or scalar preview; `truncated` is authoritative.

Engine preflight denials raise typed errors. Tools convert them into error Hashes.
After a session starts, the Engine attempts cleanup and returns a failure result.
Cleanup failure can supersede the original result with `cleanup_pending`; inspect the
durable operation's `error_code` and arrange host review for unknown effects.

Safe error codes: `INVALID_INPUT`, `NOT_AUTHORIZED`, `UNSUPPORTED_SECURITY_CAPABILITY`,
`BUDGET_EXHAUSTED`, `SESSION_UNKNOWN`, `CLEANUP_PENDING`, `APPROVAL_REQUIRED`,
`APPROVAL_STALE`, and `PROVIDER_ERROR`.

## Budgets

`Budget.new` defaults to `max_seconds: 60`, `max_steps: 12`, `max_bytes: 262_144`,
`max_concurrent: 1`, and `max_cost_usd: nil`.

`RubyLLM::Browser.configure` sets process defaults for `default_budget`,
`max_result_bytes`, `clock`, and `logger`. New contexts/policies use those defaults;
existing objects do not change. `configuration.backend` is only a reserved host slot:
contexts always require an explicitly supplied backend and never use a fallback.

- Steps count navigation, observation, extraction, and action calls, not start/cleanup.
- Bytes count retained sanitized result data, not all bytes the remote browser receives.
- Wall-clock checks refuse new calls after expiry. Stagehand request timeouts are bounded
  by remaining time. Cleanup has a separate timeout and may outlive this budget.
- Concurrency is scoped to the actor across runs. Unknown/pending cleanup holds a slot.
- `max_cost_usd` is **advisory only**. There is no cost ledger or provider hard spending
  cap in this release. Enforce billing limits in the provider/host.

## Stagehand backend status

`StagehandBackend` is unsupported for live operations in this release. It always reports
`egress_isolation: :unverified` and `act_supported?: false`. `Engine` refuses it before
the first provider request, and direct start, navigation, observation, extraction, and
Act calls also fail closed. No constructor option or injected client enables live use.

The adapter remains in the source for future qualification. Its client pins credentials
and base URL, disables retries, self-healing, CAPTCHA solving, session recording and
session logging, and requests a provider timeout. These controls do not prove egress,
TTL, billing, final-URL reporting, or cleanup. `end_session` sends no request in this
release and returns `false`; the operation remains `cleanup_pending`.

The constructor accepts `server: :remote`, `base_url:`, `timeout: 60.0`,
`custom_headers_approved: false`, `env: ENV`, and an injected `client:` for internal
contract tests. A future live implementation must verify all relevant environment
settings, egress across every browser request path, TTL and closure status, and provider
billing controls before it can advertise support.

## Configuration diagnostics

For diagnostics without network requests, use `Doctor.new(backend:).report`. It
returns `mode`, `ok`, `summary`, and `checks`. See
[Checking Configuration]({% link _core_features/diagnostics.md %}) for the backend-specific checks.

## Dependency security floors

Old Ruby installations can supply vulnerable default gems even when a developer's
lockfile audit passes. Runtime requirements explicitly exclude those versions:
`cgi >= 0.4.2, < 1`, `resolv >= 0.7.2, < 1`, `uri >= 1.0.4, < 2`, and
`zlib >= 3.2.3, < 4`. A fresh install may build native extensions for these gems.
Use a supported, patched Ruby interpreter as well; these floors do not patch Ruby or
system libraries. Audit the versions actually activated by your application, including
default gems, not just a development lockfile.

## Experimental Act

`Act.new(context:)` declares RubyLLM `requires_approval`. Its arguments are `url`,
`approval_id`, `method`, `selector`, optional `description`, and optional `arguments`.
The resolver reads the host store without consuming. Consumption immediately before
dispatch checks actor/run, exact URL/action digest, expiry, and any supplied
page/operation/session bindings. Revocation and consumption are atomic in the stores.

**Do not use this as a production authorization protocol yet.** Bindings are currently
optional; a candidate-list digest is not a DOM/target revision, and each Engine action
opens a fresh session. The same-session host approval flow required by the specification
is deferred to a later version. The Engine refuses all non-fake Act calls before starting
a session. Selector/description keyword filters are defense in depth, not semantic proof
that a click is harmless. The Stagehand adapter does not support Act in this release.

## Rails Result Delivery

After `require "ruby_llm/browser/rails"`, set `Rails.result_delivery` to a callable
accepting `operation:` and `result:`, or `nil` to disable it. `Rails.reset!` clears the
hook. The callback runs synchronously after execution and cleanup. Return values are
ignored; exceptions become `Rails::ResultDeliveryError` (`RESULT_DELIVERY_FAILED`),
which exposes `operation` and `result` to trusted recovery code. These objects are
not automatically persisted. Duplicate browser jobs do not retry delivery. Read
[Rails Result Delivery]({% link _advanced/result-delivery.md %}) for storage, access,
cancellation, and crash boundaries.

## Next steps

- Read [Rails integration]({% link _advanced/rails-integration.md %}) for durable workers and recovery.
- Read [security boundaries]({% link SECURITY_MODEL.md %}) before qualifying a live backend.
