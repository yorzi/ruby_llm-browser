# Owner action plan

Choose the release scope first, then qualify the deployment before authorizing publication.

## Current position

- Hardening submitted as `0ec34d4` to the **private** repository.
- Expanded remote CI is green: seven test jobs and the package/install/advisory job.
- Public publication remains **NO-GO**. No live session or RubyGems push is authorized.

## Your next decision

**Recommended: make 0.1 a read-only Inspect/Extract release and defer live Act.**
This avoids making the first release depend on a larger same-session approval protocol.
It does not remove the provider-security gate. Alternatively, keep the complete original
scope and implement/qualify that protocol before release.

An explicit scope decision authorizes preparing the revised specification/release pack.
It is not H1/H2 approval, consent to spend money, or permission to publish.

## Remaining work and ownership

| Gate | What you decide or provide | What the assistant can do |
| --- | --- | --- |
| Release scope / Act | Approve read-only 0.1 scope, or retain live Act as a release requirement. | Draft the scope correction and formal review pack; keep live Act disabled, or design and implement the missing session-bound flow with tests. |
| Provider qualification | Choose the actual deployment and approve its data-processing/billing owners. Later, approve a controlled test origin and bounded test plan. | Research provider controls, draft support questions, build an offline qualification harness, and identify unsupported guarantees. Run paid/live checks only after explicit authorization and security preconditions. |
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
Keep that live backend unsupported, or qualify an isolated deployment with the missing
controls. Do not flip `egress_isolation: :enforced` merely to bypass the preflight gate.

## Authorizing a later live test

Approve the provider/deployment, public test origin you control or have permission to
use, data to be sent to browser/model services, session/request/time limits, billing
owner, and spending limit. A hard monetary ceiling requires an actual provider control.
Use controlled negative fixtures, not genuine cloud-metadata or third-party private
services. Supply credentials through local secret management, never in chat or commits.

The assistant can first prepare this plan without credentials or paid calls. If required
network isolation cannot be established, do not proceed with live browsing.

## Public disclosure decision

Publishing a RubyGem makes its packaged code, guides and examples publicly downloadable,
even if the GitHub repository remains private. Approve that disclosure before publication.
Changing GitHub visibility is a separate action and is not part of submitting changes.

## Suggested next instruction

> Prepare a read-only 0.1 release scope and provider qualification plan. Keep live Act
> disabled. Do not make paid calls, publish to RubyGems, or change repository visibility.

This is a proposal for your approval, not an instruction already received.
