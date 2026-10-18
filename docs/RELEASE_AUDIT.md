---
layout: default
title: Release Audit
description: Record release fixes, provider limits, and the scope of available evidence.
---

# Release audit: 2026-10-18

**Audit snapshot before the 0.1.0 release instruction: publication was on hold; the selected first-release scope was offline read-only.**

The original 270-example suite was green, but source review and new negative tests
found security/lifecycle defects and documentation errors. Those defects are hardened
in commit `0ec34d4`. A green offline suite does not close the provider, authorization,
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
and the existing engine/store/job suites. The source repository's `docs/WORK.md` records the commands and dependency versions.

## Open live-support and publication gates

### P1: Provider-side security and protocol qualification (BR-02; blocks live support)

The gem contains no browser firewall. A custom backend's `egress_isolation: :enforced`
capability is a declaration, not independent proof. `StagehandBackend` stays
`:unverified` and disabled. No live provider egress, TTL, billing, or cleanup
qualification was performed. Stagehand 3.21 allows null navigation results, so final-URL
reporting must be verified against an actual server. Unknown starts without session IDs
have no correlation API in this adapter and cannot be automatically proven closed. Local
time alone never releases their quota. These are provider/host evidence gaps, not
mock-test tasks.

### P1: Full live Act protocol is not implemented (deferred beyond the first release)

The current Engine starts a new session for each call. Approval operation/session/page
bindings are optional, and a digest of observed action candidates does not prove DOM
or target revision. Keyword filters cannot prove semantic safety. Offline single-use
store behavior is correct, but it is not the required same-session host decision.
Live Act is disabled instead of presenting this as production-safe. Implement the
protocol in a later version. No unaudited opt-in flag should bypass this Engine refusal.

### P2: Distribution ownership and approval (BR-03 / BR-04; publication blockers)

The RubyGems API returned 404 for `ruby_llm-browser` on 2026-10-18. It was
unregistered at that check, not reserved or owned. The signed-in publisher account has
MFA disabled; this gem requires MFA, so a push will be rejected until the owner enables
it. Exact name availability, trademark/affiliation wording and owner/distributor
clearance remain open. The 26-gem runtime license metadata inventory now matches the
resolved lockfile; the Stagehand source MIT text is pinned in NOTICE. This technical
inventory is not legal clearance.

Independent H1 is complete and owner H2 approved the offline read-only scope and KPI
proposal against exact Q `22d488987517b10dcd96d2713ed3d47e8818b36b` on 2026-10-18.
The approval record is in the OddlyNiche Specs handoff. Baseline registration R and
implementation receipt remain pending. H2 does not approve RubyGems publication or the
exact release artifact.

## Limits and follow-up checks

- PostgreSQL remains untested. Local macOS Ruby 3.3.5 and the Linux Ruby 3.2/3.3/3.4
  CI combinations pass with SQLite. Rails 7 is not a supported target.
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

## Submission verification

Commit `0ec34d4` is pushed to the repository. The expanded
[GitHub Actions run](https://github.com/yorzi/ruby_llm-browser/actions/runs/39086570934)
passed all seven compatibility jobs (302 examples each) and the build/install/advisory
job, including `CORE_PACKAGE_PASS`, `CLEAN_RUNTIME_ADVISORIES_PASS`, and
`RAILS_PACKAGE_PASS`. This closes the expanded-CI follow-up, not the live-provider or
owner-approval gates. The source repository's `docs/RELEASE_ACTION_PLAN.md` records the owner decisions and follow-up actions.

## Owner scope decision and qualification follow-up (2026-10-18)

The owner selected a read-only first release, deferred the full live Act protocol to a
later version, and explicitly declined live provider calls for this qualification. The
built-in `StagehandBackend` now always reports egress as unverified and refuses live
start, navigation, observation, extraction, and Act calls. The host cannot enable it with
an `:enforced` assertion. The offline `FakeBackend` remains available.

Browserbase's [Allowed Domains documentation](https://docs.browserbase.com/platform/browser/security/allowed-domains)
describes top-frame navigation checks and does not establish blocking for iframes or
subresources. This is insufficient evidence for the required browser-side egress policy.
The [Update a Session endpoint](https://docs.browserbase.com/reference/api/update-a-session)
accepts `REQUEST_RELEASE` and may return a session in `PENDING`; the [Get a Session endpoint](https://docs.browserbase.com/reference/api/get-a-session)
exposes `status` and `endedAt`. Stagehand 3.21's `SessionEndResponse.success` only says
the request succeeded, and its SDK does not expose that status lookup. The implementation
therefore sends no Stagehand provider request, including `end_`; cleanup remains
`cleanup_pending` until future work can verify terminal status. The stubbed HTTP contract
tests now assert that no cleanup request is dispatched.

No egress, TTL, billing, or cleanup live calls were made. BR-02 remains open for any
future live backend, but it does not block the offline-only first-release scope. At the
time of this initial audit snapshot, distribution decisions and the final release
instruction were pending.

## Owner release instruction (2026-10-18)

After the initial audit snapshot, the owner selected gem version `0.1.0`, requested a
matching Git tag, instructed RubyGems publication, and requested GitHub Actions automation
for later version tags. This instruction authorizes the offline-only package release; it
does not authorize provider calls, make Stagehand supported, or implement live Act. The
approved Specs Q remains identified by its historical candidate label `0.3.0-draft`.
RubyGems publication and GitHub Pages deployment results are recorded separately from
this pre-release audit snapshot.

## Publication outcome (2026-10-18)

The owner authorized publishing the offline-only `0.1.0` package after the earlier audit
snapshot. The RubyGems trusted publisher is registered for repository `yorzi/ruby_llm-browser`,
workflow `release.yml`, and environment `release`. The corrected tagged workflow
[39110148539](https://github.com/yorzi/ruby_llm-browser/actions/runs/39110148539) passed
tagged-package verification and published the gem with GitHub OIDC. RubyGems lists
[version 0.1.0](https://rubygems.org/gems/ruby_llm-browser), published with MFA metadata;
the [GitHub Release](https://github.com/yorzi/ruby_llm-browser/releases/tag/v0.1.0)
contains the gem and checksum. The custom-domain [documentation site]({% link index.md %})
is deployed and shows `0.1.0 (stable)`.

The first tag run, [39109944660](https://github.com/yorzi/ruby_llm-browser/actions/runs/39109944660),
failed before upload because the action's optional experimental attestation patch loaded
RubyGems before Bundler and activated Ruby's default zlib. The unpublished tag was moved
to a workflow fix that disables that optional patch; OIDC publishing remains active.
This release does not close provider qualification: no live egress, TTL, billing, or
cleanup calls were made. Stagehand remains unsupported, and full live Act remains deferred.
