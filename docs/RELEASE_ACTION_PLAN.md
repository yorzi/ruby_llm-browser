---
layout: default
title: Release Action Plan
description: Record the offline first-release decision and the automated gem release path.
llms: false
---

# Release action plan

The owner selected the offline-only first release as `0.1.0`, authorized its publication,
and requested tag-based release automation. This plan preserves the live-provider limits
and records the release checks.

## Current position

- Hardening baseline: `0ec34d4`.
- Expanded remote CI is green: seven test jobs and the package/install/advisory job.
- Owner decision on 2026-10-18: first release is read-only; defer live Act and mark the
  built-in Stagehand backend unsupported until egress and cleanup are qualified.
- No live provider calls are authorized or were run for this decision.
- Independent H1 and owner H2 are complete for exact candidate Q
  `22d488987517b10dcd96d2713ed3d47e8818b36b`. H2 approves handoff, not RubyGems publication.
- The RubyGems page for `ruby_llm-browser` returned 404 during the pre-release check on
  2026-10-18; that did not reserve the name. The resolved 26-gem runtime license inventory
  matches installed gemspec metadata; Stagehand is covered by its pinned source MIT text.
- The owner later instructed publication of gem version `0.1.0`; that instruction is
  separate from H2's handoff approval. RubyGems MFA is enabled on the signed-in publisher
  account. Trusted publishing must match this repository's `release.yml` workflow and
  `release` environment.

## Release scope

The first version supports offline `FakeBackend` operations. `StagehandBackend` remains in
the source but cannot start or operate on a live session. The full same-session Act
protocol is deferred to a later version. H1/H2 approved this scope for handoff against
exact Q `22d488987517b10dcd96d2713ed3d47e8818b36b`; the approved Specs candidate label
`0.3.0-draft` is historical provenance. The package and Git release use `0.1.0`.

## Remaining work and ownership

| Gate | What you decide or provide | What the assistant can do |
| --- | --- | --- |
| Release scope / Act | H2 approved the read-only scope and KPI proposal against exact Q. Live Act remains a later-version feature. | Keep the Stagehand adapter disabled and preserve the H2 decision in release docs. |
| Provider qualification | No live call is authorized for the first release. A later live release needs a named deployment and approval of data-processing/billing owners. | Record the unsupported egress and cleanup guarantees. Do not use a host assertion as qualification. |
| Name and account | The owner authorized publication as `ruby_llm-browser`; the account has MFA enabled. | Recheck name availability at publication and use the pending trusted publisher configured for this repo and workflow. |
| Formal approval | H1 and H2 are complete for exact Q; C/R registration and implementation baseline receipt remain pending. | Preserve the historical approval. Do not represent H2 as RubyGems authorization; the owner's later release instruction supplies that authorization. |
| Publication | Owner instructed publication of package version `0.1.0`. | Verify the matching tag, run the release workflow, then record the RubyGems, GitHub Release and Pages outcomes. |

## Provider questions to resolve before live tests

1. Can the actual browser enforce approved destinations and public IP ranges at
   connection time across navigation, redirect hops, subresources, iframes, popups,
   WebSockets and DNS rebinding? A Ruby allowlist is insufficient.
2. Does the actual Stagehand server return a verified final top-level URL? The SDK
   permits null navigation results; the gem refuses to invent provenance.
3. How are session TTL and confirmed closure enforced? Is a start with a lost response
   recoverable by correlation? If not, unknown starts must remain held for host review.
4. Which provider-side billing controls exist? The gem's `max_cost_usd` field is
   advisory, not an enforceable currency cap.

If the provider cannot meet a required guarantee, a test passing once is not a substitute.
Keep the Stagehand backend unsupported until the missing controls have been qualified.
The current adapter does not accept `egress_isolation: :enforced`; do not add a host
assertion merely to bypass the preflight gate.

## Authorizing a later live test

Approve the provider/deployment, public test origin you control or have permission to
use, data to be sent to browser/model services, session/request/time limits, billing
owner, and spending limit. A hard monetary ceiling requires an actual provider control.
Use controlled negative fixtures, not genuine cloud-metadata or third-party private
services. Supply credentials through local secret management, never in chat or commits.

The assistant can first prepare this plan without credentials or paid calls. If required
network isolation cannot be established, do not proceed with live browsing.

## Provider boundary

The release instruction does not authorize provider calls or live browsing. Keep
Stagehand and live Act disabled until the missing provider guarantees are separately
qualified and approved. A Ruby source URL allowlist is not browser-side egress proof.
