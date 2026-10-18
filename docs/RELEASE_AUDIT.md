# Release audit: 2026-10-18

**Decision: NO-GO for public publication or production claims.**

The original 270-example suite was green, but source review and new negative tests
found security/lifecycle defects and documentation errors. Those defects are hardened
in this working tree. A green offline suite does not close the provider, authorization,
name/license, or specification-governance gates below. Nothing has been published.

## Fixed findings

| Severity | Finding | Correction / evidence |
| --- | --- | --- |
| High | A stale reserved copy or duplicate worker could start an operation again. | Atomic `claim_start`, exact fence and legal-transition checks; stale-copy and independent-connection races. |
| High | Locking existing open rows did not serialize an actor's first concurrent reservations. | Durable actor lock row written before quota checks, including an initially empty actor. |
| High | Cancellation released a live session's quota and hid it from the reaper. | Cancellation flag plus pending cleanup; quota held until exact-session closure is confirmed. |
| High | Cancellation during start or a persistence exception could bypass cleanup/session tracking. | Persist returned identity across cancellation; ensure-style close after post-start failures; regressions. |
| High | Stagehand reconciliation always returned unknown, so the reaper did not close known sessions. | Reaper fences before I/O and attempts known-session cleanup without requiring an active reconciliation response. Failed writes are reported as failed. |
| High | Model byte requests overrode host limits, operation bytes were not enforced, and cleanup overwrote counters. | Minimum of model/policy/remaining budget; retained accounting; exact encoded-byte bounding. |
| High | Extraction provider data was not validated; malformed schema shapes could pass or raise untyped errors. | JSON Schema meta-validation plus instance validation before returning data. |
| High | Nested mutable host objects could change frozen policy/approval/schema objects. | Defensive copies and immutable host bindings. |
| High | A clean install activated vulnerable Ruby default gems despite a green development lockfile audit. | Explicit patched CGI, DNS resolver, URI and zlib dependency floors; audit both the resolved lockfile and clean runtime. |
| High | Live Act accepted incomplete grants despite missing same-session/target proof. | Engine now refuses every non-fake Act before start. Production protocol remains a blocker, not a claimed fix. |
| Medium | SDK response failures/missing identities could be treated as closed or successful; final URL was guessed. | Unknown starts remain reserved; unsuccessful responses are refused; missing final URL fails closed. |
| Medium | Provider defaults permitted self-healing/CAPTCHA solving and logging; relevant ENV could drift after qualification. | Explicit disabled options; snapshot recheck; remaining-time request timeout; real-SDK HTTP regressions. |
| Medium | URL/selector progress, parser errors and Active Job arguments exposed avoidable data. | Coarse progress, generic parser/backend failures, URL query redaction, disabled job argument logging. |
| Medium | Duplicate idempotency keys could select a different queued request; factory could use a different store. | Payload/budget digest binding and job/context store identity checks. |
| Medium | Durable timestamp precision could reject a valid direct Engine call using a real clock; configured defaults were ignored. | Return canonical stored identities, honor process budget/result defaults, and test both real clocks and configuration. |
| Medium | Rails generator command did not resolve (`RubyLLM` underscored incorrectly). | Explicit namespace, lookup test, generated migration up/down test. |
| Medium | README used `egress_isolated`, omitted required `schema:`, passed numeric IDs, and misstated return type. | Runnable offline README plus API/Rails guides and tested snippets. |
| Medium | Built gem omitted guides/examples linked by the README; dependency range admitted untested Stagehand minors. | Package includes docs/examples; Stagehand restricted to 3.21.x; packaged-link checks. |
| Low | Changelog implied a release, CI missed the RubyLLM minimum, and Doctor overstated readiness. | Unreleased changelog, compatibility matrix, public Chat API tests across versions, qualification caveat in Doctor. |

The first clean runtime activated CGI 0.4.1 (CVE-2025-27219/27220), Resolv 0.3.0
(CVE-2026-80212/80213), URI 0.13.1 (CVE-2025-27221/61594), and zlib 3.1.1
(CVE-2026-27820). The project lockfile did not enumerate all of these default gems.
Patched runtime dependency floors close this resolution gap. The native interpreter
and its system libraries still require normal host security updates.

The new audit regressions were first run against the original implementation and
demonstrated the limit/schema/start/cancellation failures before correction.
Primary evidence: `spec/security/release_audit_spec.rb`,
`spec/integration/{concurrent_store,stagehand_http,generator,documentation}_spec.rb`,
and the existing engine/store/job suites. See [WORK](WORK.md) for commands and versions.

## Open publication blockers

### P1: Provider-side security and protocol qualification (BR-02)

The gem contains no browser firewall. `egress_isolation: :enforced` trusts a host
assertion. No live provider egress, TTL, billing, or cleanup qualification was performed.
Stagehand 3.21 allows null navigation results, so final-URL reporting must be verified
against an actual server. Unknown starts without session IDs have no correlation API
in this adapter and cannot be automatically proven closed. Local time alone never
releases their quota. These are provider/host evidence gaps, not mock-test tasks.

### P1: Full live Act protocol is not implemented

The current Engine starts a new session for each call. Approval operation/session/page
bindings are optional, and a digest of observed action candidates does not prove DOM
or target revision. Keyword filters cannot prove semantic safety. Offline single-use
store behavior is correct, but it is not the required same-session host decision.
Live Act is now disabled instead of presenting this as production-safe. Implement the
protocol or obtain an explicit read-only scope revision before calling the full spec
complete. No unaudited opt-in flag should bypass this Engine refusal.

### P2: Distribution ownership and approval (BR-03 / BR-04)

RubyGems returned 404 for `ruby_llm-browser` on 2026-10-18: the name is unregistered,
not reserved or owned. RubyGems account ownership and naming/affiliation clearance are
unconfirmed. Runtime license metadata was inspected and Stagehand's pinned repository
MIT text was fetched, but final distribution review belongs to the owner. The existing
specification still records separate H1/H2 review gates; engineering work does not
grant those approvals.

## Limits and follow-up checks

- PostgreSQL and multiple OS/Ruby combinations need the new CI/DB matrix; only local
  Ruby 3.3.5 and SQLite are exercised here. Rails 7 is not a supported target.
- A global reaper cannot route between backend credential configurations; use one
  configuration per scoped store until provider identity is durably represented.
- `max_cost_usd` is advisory. No provider-enforced currency cap or cost ledger exists.
- Retained-output bounds are not remote-response, browser-memory, or bandwidth caps.
- Sanitization is not a universal secret/PII detector. Host logs, queue arguments,
  database contents and authenticated/private content require separate protection.
- Job return values are not durable result delivery. Hosts need explicit authorized
  result storage if they want it. Reservation and enqueue are not a transactional outbox.
- The release hardening changes the development schema. Follow the additive migration
  guidance; do not discard existing operation/approval records.

## Checks completed

Full offline suites run against RubyLLM 2.0.0 and 2.1.1, Rails components 8.0.5.1 and
8.1.4, Stagehand 3.21.0, and SQLite 2.10.0 on Ruby 3.3.5: **302 examples, 0 failures**
in each combination, with **89 Ruby files, no RuboCop offenses**. SDK HTTP requests are stubbed,
with all other network requests disabled. A fresh ruby-advisory-db check reports no
known vulnerable dependencies (database commit
`fa2295251efb3b0d1a300e5ce8ad700ff1f1b485`). This is a point-in-time dependency check,
not a guarantee of no vulnerabilities. Fresh installation also passes the core/Rails
examples and installed generator/migration, and the activated clean core runtime is
checked separately against advisories. Artifact verification is recorded in WORK.
