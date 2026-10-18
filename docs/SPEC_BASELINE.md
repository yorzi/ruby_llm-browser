---
layout: default
title: Specification Baseline and Provenance
description: Record product intent, evidence sources, and project ownership boundaries.
llms: false
---

# Specification baseline and provenance

This repository is the independent implementation of the `ruby_llm-browser` Gem. It is
the source of truth for code, tests and the WORK ledger. The product intent lives in a
separate specifications repository; this file records exactly which baseline was used.

## Baseline

| Field | Value |
| --- | --- |
| Intent source repository | `yorzi/oddlyniche`, folder `ruby-llm-browser` |
| Reviewed candidate Q | `22d488987517b10dcd96d2713ed3d47e8818b36b` |
| H2 approval/content commit C | `678f9faed6dfdd8e55a7c54566f94cfa1ad1bc0a` |
| Registration commit R | Pending; not registered |
| Source commit date | 2026-10-18 |
| Spec baseline version | `0.3.0-draft` |
| Spec lifecycle | `HANDOFF_READY`; independent H1 complete and owner H2 approved for exact Q |
| Implementation authorized | 2026-10-17; H2 handoff approved 2026-10-18 (does not authorize RubyGems publication) |
| Gem | `ruby_llm-browser` |
| Namespace | `RubyLLM::Browser` |
| Require path | `ruby_llm/browser` |
| Working repository | `yorzi/ruby_llm-browser` |

## Pinned upstream facts used (source-read at the spec baseline)

| Dependency | Pin | Notes |
| --- | --- | --- |
| Stagehand Ruby SDK | `stagehand` 3.21.0, tag `v3.21.0` (`b389c6e`) | Ruby `>= 3.2`; REST client, not a sandbox |
| RubyLLM | 2.0.0 and 2.1.1 | `Chat#with_tools` accepts Tool instances; `requires_approval` since 2.0; `progress`/`defer` since 2.1 |

## S0 decisions recorded here

1. **Hooks:** `Tool#progress` and `Tool.defer` exist only in RubyLLM 2.1+. This Gem
   **feature-detects** them instead of raising the gemspec floor to `>= 2.1`, so the
   supported floor stays `>= 2.0, < 3` (matching the 2.0.0 / 2.1.x matrix).
2. **Stagehand dependency:** declared as a runtime dependency (`~> 3.21`) for the
   experimental adapter and cleanup path, but **required lazily** so requiring the Gem
   never reads `STAGEHAND_*`/`BROWSERBASE_*`/`MODEL_API_KEY` environment variables or
   triggers the SDK's local-server binary download. The adapter is unsupported for live
   operations in the first release.
3. **Rails:** optional, loaded only via `require "ruby_llm/browser/rails"`.
4. **Frame and lib style:** explicit `require_relative` chain (no Zeitwerk loader) so the
   load graph is fully predictable and the no-Rails guarantee is easy to prove.

## Audit corrections (2026-10-18)

- Restrict Stagehand to `~> 3.21.0`, not all future 3.x minors; add JSONSchemer for
  schema/instance validation.
- The Engine now refuses live Act. The full same-session/page/target protocol in this
  baseline is not implemented; earlier fake-only PASS claims did not establish it.
- Final URLs are no longer inferred when navigation results omit them. The pinned SDK
  permits null results, so actual server behavior must be qualified.
- SQLite's ignored SELECT FOR UPDATE needs an actual write lock; actor-lock rows and
  atomic start claims now enforce reservations and duplicate-delivery safety.
- Cancellation holds quota after dispatch until cleanup is confirmed. Prior terminal
  cancellation and swallowed reaper-write failures were not evidence of safe cleanup.
- No cost ledger or hard currency cap is implemented. Retained-result limits do not
  cap provider response allocations or browser bandwidth.

These corrections harden engineering behavior. The owner separately approved exact
Specs candidate Q `22d488987517b10dcd96d2713ed3d47e8818b36b` at H2 on 2026-10-18;
that approval does not authorize live use or RubyGems publication. See
[the audit]({% link RELEASE_AUDIT.md %}) for unresolved protocol/product decisions.

## Outstanding blockers (carried from the spec baseline)

These are **not** satisfied by this repository yet. BR-02 blocks live support; BR-03 and
BR-04 block publication. They are reproduced in intent so they cannot be quietly dropped.

- **BR-02 / live blocker:** a real browser provider must prove browser-side egress
  isolation across navigation, redirects, iframes, popups, subresources, WebSockets and
  metadata routes before live mode is enabled. The first release keeps Stagehand
  unsupported and makes no live calls. Ruby-side URL/DNS checks cannot prove egress.
- **BR-03 / release blocker:** confirm the exact RubyGems name at publication, publisher
  account and MFA, and owner/distributor clearance for trademark/affiliation wording.
  The 2026-10-18 API check returned 404, which means unregistered at that check only;
  it does not reserve or establish ownership. The 26-gem runtime license metadata
  inventory now matches the resolved lockfile; the Stagehand MIT text is pinned below.
  This technical inventory is not legal clearance.
- **BR-04:** independent H1 and owner H2 are complete for the exact Q above. Baseline
  registration R and the exact-artifact publication approval remain pending. H2 does
  not authorize RubyGems publication.

## Owner scope decision (2026-10-18)

The owner selected a read-only first release, deferred the full live Act protocol to a
later version, and declined live provider calls. This narrows the first release to the
offline `FakeBackend` and does not close BR-02 for later live support. Stagehand always
reports unverified egress, refuses live operations, and sends no provider call including
cleanup. Unresolved sessions remain `cleanup_pending`. H1/H2 are approved for exact Q;
registration R, BR-03 owner/distributor clearance, and exact-artifact publication approval
remain open.

## Evidence rule

Every functional requirement case records test ID, exact versions, run command, fixture,
result (`PASS` / `FAIL` / `NOT RUN`) and date in `docs/WORK.md`. Mocked tests never
prove remote browser egress. `NOT RUN` is recorded as `NOT RUN`, never as `PASS`.
