# Security model

Understand what the gem enforces and what a deployment must prove independently.

After reading this guide, you will know:

- Which inputs are trusted.
- Why local URL validation does not secure a remote browser.
- How sessions, cancellation, unknown outcomes, and secrets are handled.

## Trust boundaries

The host owns authentication, actor/run authorization, consent, provider configuration,
source grants, budgets and approval issuance. The model, browser page and provider
payload are untrusted. A `Context` expresses a host decision; it does not authenticate
that decision. Unscoped store APIs are for trusted workers, not public controllers.

## Destinations and egress

URL validation rejects unsupported schemes/ports, userinfo, ambiguous numeric IP forms,
unapproved hosts, and local/private/link-local/metadata/reserved IP answers, including
IPv6 and IPv4-mapped addresses. Real DNS validation is enabled by default.

These checks run in Ruby. They do **not** enforce a remote browser's DNS view, redirects,
iframes, popups, WebSockets, subresources, scripts or connection-time rebinding.
`Policy#authorize_egress!` refuses an unverified backend before starting a session.
`egress_isolation: :enforced` records a **host assertion**, not independent proof and
not installed firewall enforcement.

Before a host makes that assertion, it must test every request path against a controlled
public test origin and prove private/metadata addresses remain unreachable at connection
time. Asset origins must be explicitly approved by the network layer. Also qualify
local-mode browsers; a local browser is not a sandbox by default.

Stagehand navigation results may be null. The adapter refuses to invent a final URL in
that case. A live deployment must establish how its actual server reports a verified
current URL; the SDK schema alone is not evidence. Returned page data remains untrusted.

## Operation identity and recovery

- Reserve operation identity and actor quota before start. Claim reserved-to-starting
  atomically, checking the exact fence. A duplicate job cannot start a second session.
- Rails idempotency keys bind the exact payload and budget. Per-actor write-lock rows
  serialize even the first two reservations when there are no open operation rows.
- Persist returned session identity before further calls, including a return that races
  with cancellation. A persistence exception still triggers a cleanup attempt.
- Disable SDK retries at client and request levels. The SDK's idempotency option is not
  treated as a provider guarantee: its client has no configured idempotency header.
- Cancellation cannot undo a dispatched request. It fences stale workers and holds quota
  in `cleanup_pending` until provider-confirmed closure. A never-started reservation can
  become terminal immediately.
- A reaper fences before reconciliation/cleanup. It attempts to close known session IDs
  even if reconciliation is unavailable. Database/provider failures never count as
  successful cleanup. A local deadline or idle TTL is not proof of provider expiry.
- A start whose session ID is unknown cannot be automatically reconciled by the current
  Stagehand adapter. Hold quota and escalate to host/provider review. Never start a new
  operation merely to conceal or retry an uncertain outcome.

SQLite concurrency is tested with independent connections. PostgreSQL remains untested
in this audit. A global reaper must use the same backend configuration as the operations
it sees; multi-backend routing is not represented in the schema.

## Actions and approvals

**Live Act is disabled at the Engine boundary**, including when a backend advertises
action support. Offline simulation checks RubyLLM approval integration, read-only grant
resolution, atomic single-use consumption, actor/run/action/URL and supplied revision
bindings, expiration, revocation, replay, and unknown dispatch outcomes.

That is not the complete production protocol: operation/session/page bindings are
optional on the current Approval object; a candidate-action hash is not a DOM/target
revision; and each Engine call starts a new session. Implement and verify same-session
host approval and fresh target/policy checks before enabling live Act.

Keyword filters on selectors/descriptions cannot prove semantic safety. An innocuously
named button can purchase or publish. They are only defense in depth. Purchases,
posting, account changes, credentials and access-control bypass remain unsupported.

## Output, schema, and secret handling

Extraction data is validated against the host schema before redaction/truncation. Model
byte requests cannot increase policy ceilings. The retained serialized JSON fits both
the policy ceiling and remaining operation bytes, including UTF-8 and escaped text.
These limits do not cap remote browser bandwidth or provider response allocation.

The redactor removes credential-like fields, known credential literals and WebSocket
DevTools endpoints. URL provenance removes userinfo, fragments and credential-like
query values. Error messages do not include raw SDK bodies or parser input. Progress
messages contain no raw URL/selector. Active Job argument logging is disabled.

This is **not a general secret or PII detector**. Arbitrary page secrets, screenshots,
credentials under innocuous names and secrets not supplied to the redactor cannot be
reliably identified. Do not browse authenticated/private content; do not put credentials
in URLs or instructions; prevent host/RubyLLM/HTTP debug logging from recording payloads.
Queue data and approval action arguments may persist in the host database; encrypt,
scope and retain them appropriately. No browser cookies/profiles are supplied for reuse.

The adapter passes explicit SDK credentials/base URL and rejects unapproved custom
headers. Changes to relevant process environment values invalidate qualification.
Environment injection is for diagnostics/tests; the real SDK reads actual process ENV.
Do not mutate ENV during concurrent browser work. Session requests disable self-healing,
CAPTCHA solving and provider recording/logging; actual provider behavior still needs
qualification. Cleanup and TTL are best-effort, and cost values are advisory.

## Next steps

- Follow [Rails recovery](RAILS.md) to schedule cleanup and protect status access.
- Review [the release audit](RELEASE_AUDIT.md) for evidence and remaining blockers.
