# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project aims to
follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Opt-in `Rails.result_delivery` receives a sanitized `Result` and its operation
  after execution and cleanup. Hosts own persistence, authorization and recovery.
- `Rails::ResultDeliveryError` reports failed delivery with retained in-process
  operation/result objects. Callback errors do not leak through exception causes.

### Fixed

- Suppress result delivery from cancelled or fenced workers. A delivery failure
  preserves session state; duplicate jobs never repeat browser work or delivery.

## [0.2.0] - 2026-10-19

### Added

- `RubyLLM::Browser.tools(context:, schema:)` builds fresh Inspect and Extract
  instances for `chat.with_tools(*tools)`. It never includes Act or dispatches work.
- Agent validation commands, an offline development workbench, and desktop/mobile
  Chrome workflows with fixture screenshots. Browser libraries are development-only.

### Changed

- Doctor reports `mode: :offline`, `:live`, or `:unconfigured`. FakeBackend checks
  skip Stagehand SDK and provider environment checks. Custom backends no longer
  receive unrelated Stagehand credential warnings. Stagehand remains blocked.

## [0.1.0] - 2026-10-18

### Fixed

- Atomic start claims, actor quota locking, payload-bound idempotency, exact fence/state
  checks, cancellation quota retention, and cleanup after post-start persistence errors.
- Reaper fencing before cleanup and recovery of known sessions without a correlation API.
- Host/operation output ceilings, UTF-8/escaped-JSON bounds, retained byte accounting,
  malformed schema handling, and provider extraction schema validation.
- Defensive policy/approval/schema copies, safer progress/errors/provenance, and suppressed
  Active Job argument logging.
- Real-clock durable timestamp round-trips and effective process budget/result defaults.
- Stagehand response validation, explicit disabled self-healing/CAPTCHA solving/recording,
  environment-drift rejection, remaining-time timeouts, and no guessed final URL.
- Rails install generator namespace, README API errors, shipped documentation/examples,
  and RubyLLM 2.0/2.1 public-API compatibility tests.

### Security

- Require patched CGI, DNS resolver, URI and zlib versions instead of accepting old
  vulnerable default gems on a clean Ruby installation.
- The first-release scope is offline read-only. Stagehand remains unsupported until
  provider egress and confirmed cleanup are qualified; no live calls were made. Full live
  Act is deferred to a later version, while offline Act simulation remains available.
- See `docs/RELEASE_AUDIT.md` for findings, mitigations and residual limits.

The first implementation milestone. Everything below is proven offline against the fake
backend and an in-memory SQLite database; **no live browser provider call has been run**,
and mocked tests never establish remote egress isolation, TTL or billing limits.

### Added

- Plain-Ruby Gem core (`require "ruby_llm/browser"`) with a manual require chain, no Rails
  and no provider credentials loaded on require.
- Read-only `RubyLLM::Browser::Inspect` and `Extract` tools; `Extract` takes a
  host-pinned schema instead of a model-supplied one.
- Simulation-only `RubyLLM::Browser::Act` (never registered by default) with a read-only RubyLLM
  approval resolver and an atomic, digest-bound, single-use approval consumed in `execute`.
- Source policy: URL normalization with userinfo/scheme/port and ambiguous-IP rejection,
  allowlist matching, and fail-closed egress qualification that returns
  `UNSUPPORTED_SECURITY_CAPABILITY` before any session when a backend cannot prove
  browser-side egress isolation.
- Durable operation lifecycle (`reserved → starting → active → closing → closed`, plus
  `unknown` / `cleanup_pending` / `cancelled`), fencing and per-actor concurrency budgets,
  with in-memory and ActiveRecord stores.
- Official Stagehand Ruby SDK adapter (loaded lazily) that passes every client argument
  explicitly, sets `max_retries: 0` on effectful calls, drops `cdp_url`, and reports honest
  capabilities.
- Bounded, sanitized `Result` with provenance, plus a redactor that strips secrets,
  cookies and DevTools URLs.
- Read-only preflight `Doctor`.
- Optional Rails 8 adapter (`require "ruby_llm/browser/rails"`): ActiveRecord operation and
  approval stores, a scoped Active Job with fence/cancel handling, a cleanup reaper, a
  canonical schema module and an install generator with migration.
- Offline examples, documentation and an FR evidence ledger (`docs/WORK.md`).
