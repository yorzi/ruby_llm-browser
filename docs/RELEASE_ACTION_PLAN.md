---
layout: default
title: Release Action Plan
description: Record the offline first-release decision and the automated gem release path.
llms: false
---

# Release action plan

The owner selected the offline-only first release as `0.1.0`, authorized its publication,
and requested tag-based release automation. Version `0.1.0` is published. This plan records
the outcome and preserves the live-provider limits for future work.

## Current position

- Hardening baseline: `0ec34d4`; release workflow fix: `8f0e8e7`.
- Expanded remote CI passed before release. Tagged verification and publication passed in
  [release run 39110148539](https://github.com/yorzi/ruby_llm-browser/actions/runs/39110148539).
- RubyGems lists [ruby_llm-browser 0.1.0](https://rubygems.org/gems/ruby_llm-browser).
  Publication used the registered trusted publisher for `yorzi/ruby_llm-browser`,
  `.github/workflows/release.yml`, and environment `release`; MFA publication is recorded.
- The [GitHub Release](https://github.com/yorzi/ruby_llm-browser/releases/tag/v0.1.0)
  includes the gem and `SHA256SUMS`. The gem SHA-256 is
  `0159bf5b4d50fc1a5d129ce8e6d8235ff9a5181704d5e8168c2facb429808ed3`.
- The post-release Pages build passed in
  [Docs run 39110265391](https://github.com/yorzi/ruby_llm-browser/actions/runs/39110265391).
  The [custom-domain docs site]({% link index.md %}) shows `0.1.0 (stable)`.
- The first publish attempt failed before upload because the action's optional
  experimental attestation patch activated Ruby's default zlib before Bundler. The
  unpublished tag was moved to a fix that disables that patch; OIDC publication remains.
- Owner decision on 2026-10-18: first release is read-only; defer live Act and mark the
  built-in Stagehand backend unsupported until egress and cleanup are qualified.
- No live provider calls are authorized or were run for this decision.
- Independent H1 and owner H2 are complete for exact candidate Q
  `22d488987517b10dcd96d2713ed3d47e8818b36b`. H2 approves handoff, not RubyGems publication.
- The pre-release exact-name check returned 404 on 2026-10-18; it did not reserve the
  name. Version `0.1.0` is now registered on RubyGems. The resolved 26-gem runtime license
  inventory matches installed gemspec metadata; Stagehand is covered by its pinned source
  MIT text.
- The owner instructed publication separately from H2's handoff approval. The gem requires
  MFA, and RubyGems records the successful publication as MFA-protected.

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
| Name and account | The owner authorized publication as `ruby_llm-browser`; version `0.1.0` is registered and MFA-protected. | Use the existing trusted publisher for future tags; do not add a long-lived RubyGems API key to GitHub. |
| Formal approval | H1 and H2 are complete for exact Q; C/R registration and implementation baseline receipt remain pending. | Preserve the historical approval. Do not represent H2 as RubyGems authorization; the owner's later release instruction supplies that authorization. |
| Publication | Version `0.1.0` is published under tag `v0.1.0`; GitHub Release assets and stable Pages are live. | For each later version, align gem/docs/changelog metadata and push the matching tag. The release workflow verifies tests, advisories and package contents before OIDC publishing; Docs deploys after success. |

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
