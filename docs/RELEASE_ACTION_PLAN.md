---
layout: default
title: Owner Action Plan
description: Choose the release scope, qualify the deployment, and resolve publication gates.
llms: false
---

# Owner action plan

The first-release scope is selected. Resolve the remaining governance and distribution
gates before attempting publication.

## Current position

- Hardening baseline: `0ec34d4`.
- Expanded remote CI is green: seven test jobs and the package/install/advisory job.
- Owner decision on 2026-10-18: first release is read-only; defer live Act and mark the
  built-in Stagehand backend unsupported until egress and cleanup are qualified.
- No live provider calls are authorized or were run for this decision.
- The owner requested a RubyGems publication attempt. Publication is still on hold while
  H1/H2, naming, license, and exact-artifact checks remain open.

## Your next decision

The first version supports offline `FakeBackend` operations. `StagehandBackend` remains in
the source but cannot start or operate on a live session. The full same-session Act
protocol is deferred to a later version. This scope decision is not H1/H2 approval or
RubyGems publication clearance.

## Remaining work and ownership

| Gate | What you decide or provide | What the assistant can do |
| --- | --- | --- |
| Release scope / Act | Review the read-only first-release scope. Live Act remains a later-version feature. | Keep the Stagehand adapter disabled; update the release and formal review packs. |
| Provider qualification | No live call is authorized for the first release. A later live release needs a named deployment and approval of data-processing/billing owners. | Record the unsupported egress and cleanup guarantees. Do not use a host assertion as qualification. |
| Name and account | Confirm the publisher identity, maintain a RubyGems account with MFA, and accept the naming/affiliation/license review. | Recheck availability, assemble license evidence, prepare release metadata and a trusted-publishing workflow. An unregistered name is not reserved; do not publish a placeholder to claim it. |
| Formal approval | Review the specification artifacts and make the required owner decisions. | Prepare the review materials and traceability; never mark human approval on your behalf. |
| Publication | Explicitly approve the exact release artifact and public disclosure. | Build, verify, tag and publish only within the final authorization; provide checksums and a post-release verification report. |

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

## Public disclosure decision

Making the GitHub repository public exposes its tracked files, including files outside the
gem package. Review the repository contents before changing visibility. RubyGems
publication is a separate disclosure and still needs approval for the exact release.

## Suggested next instruction

> Prepare and review the read-only first release. Keep Stagehand and live Act disabled.
> Do not make provider calls. Attempt RubyGems publication only after H1/H2, name/license,
> and exact-artifact gates pass.

The owner selected this first-release scope on 2026-10-18. The publication request does
not override the outstanding review and distribution gates.
