# Security model (detailed)

This document complements [`../SECURITY.md`](../SECURITY.md). It describes the boundaries
the Gem enforces, the boundaries it explicitly cannot enforce, and how each maps to tests.

## Trust model

| Source | Trust |
| --- | --- |
| Host application (actor, run, grants, budgets, consent) | trusted |
| Backend/provider configuration (explicit, host-supplied) | trusted |
| Model arguments | untrusted input, validated |
| Page content and model output | untrusted data, never instructions or proof |

Page text can never change policy, grant an action or elevate a tool's permissions. A
successful extraction is evidence with provenance, not verification of a claim's truth.

## Boundary 1 — destinations (SSRF)

`Policy#authorize_destination!` normalizes a URL and denies anything that is not an
explicitly allowed host over an allowed scheme/port. Denials cover userinfo, unsupported
schemes, non-approved ports, ambiguous IP encodings (decimal/octal/hex), loopback,
private, link-local, multicast and cloud-metadata addresses in IPv4, IPv6 and
IPv4-mapped forms, and hostnames whose DNS answers include any such address.

This raises the barrier against `localhost`, private-network and metadata SSRF and against
simple DNS rebinding, **but it runs in the Ruby process.** It cannot control what a
remote browser does. Therefore:

## Boundary 2 — egress (fail closed)

Before any session starts, `Policy#egress_qualified?` must be satisfied. A backend
advertises its posture through `Backend#capabilities`. If a backend cannot claim enforced
egress isolation — every navigation, redirect hop, iframe, popup, subresource and
WebSocket connection staying within approved destinations and public address ranges at
connection time — the Gem raises `UNSUPPORTED_SECURITY_CAPABILITY` and never contacts the
provider. A Ruby allowlist is never presented as a remote SSRF guarantee.

The fake backend declares enforced isolation because it performs no network I/O. The
Stagehand backend reports `:unverified` unless the host asserts `egress_isolated: true`
after qualifying the provider itself.

## Boundary 3 — operations, sessions and money

- An operation ID, actor/run binding, concurrency slot and budget are reserved
  **before** the first remote call. Duplicate jobs attach to the stored operation.
- Session creation, navigation, `act` and `end_` are issued with `max_retries: 0`. The
  SDK's default of two retries is never used on effectful paths, and Active Job retries
  are fenced by operation identity so they cannot spawn a second session.
- The provider's session ID is persisted before any further call. An unresolved start or
  action becomes `unknown`; an attempt at cleanup that did not succeed becomes
  `cleanup_pending`. Neither is reported as `closed`, and the budget reservation is held
  until closure or expiry is confirmed.
- Cancellation marks the operation, fences stale workers and stops new calls. It cannot
  undo an already-dispatched remote request.

## Boundary 4 — approval (Act)

`RubyLLM::Browser::Act` is never registered by default. The RubyLLM `requires_approval`
resolver only *reads* the host `ApprovalStore` (it may be called repeatedly). The atomic
`consume_once`, together with the URL / page-revision / action-digest checks, happens
inside `execute` immediately before dispatch. An approval binds actor, run, URL, page
revision, exact normalized action digest and expiry. Missing, expired, revoked,
cross-actor, replayed or stale approvals dispatch nothing. A provider timeout **after**
dispatch is `unknown` and requires a new explicit decision; it is never replayed.

## Boundary 5 — secrets and privacy

- API keys, cookies, `cdp_url` and raw page dumps never appear in tool results, model
  messages, logs or errors. `sessions.start` returns a full-control DevTools URL; the
  Gem treats it as a secret and drops it at the adapter boundary.
- All Stagehand client arguments are passed explicitly. The Gem never reads SDK
  credential/base-URL environment defaults, and because the SDK always merges
  `STAGEHAND_CUSTOM_HEADERS`, the backend refuses to start unless the host approved those
  headers.
- Data sent to a remote browser/model is disclosed to the host so it can obtain consent.

## What this Gem does not do

No authenticated-cookie reuse, no credential scraping, no CAPTCHA/age/access bypass, no
arbitrary JS/shell, no automatic purchases, posting or account changes, no hidden paid
fallback, and no second browser engine.

## Evidence and honest limits

`spec/security` exercises every denial path above against the fake backend and injected
clients. Those tests prove the Gem's decision logic. They do **not** prove any provider's
network isolation, TTL enforcement or billing ceiling. Live qualification is a separate,
owner-authorized step, and until it exists live mode stays disabled.
