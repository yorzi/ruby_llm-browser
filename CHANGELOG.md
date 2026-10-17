# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project aims to
follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-10-17

The first implementation milestone. Everything below is proven offline against the fake
backend and an in-memory SQLite database; **no live browser provider call has been run**,
and mocked tests never establish remote egress isolation, TTL or billing limits.

### Added

- Plain-Ruby Gem core (`require "ruby_llm/browser"`) with a manual require chain, no Rails
  and no provider credentials loaded on require.
- Read-only `RubyLLM::Browser::Inspect` and `Extract` tools; `Extract` takes a
  host-pinned schema instead of a model-supplied one.
- Opt-in `RubyLLM::Browser::Act` (never registered by default) with a read-only RubyLLM
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
