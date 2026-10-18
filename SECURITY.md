# Security Policy

## Reporting a vulnerability

Report security issues privately via GitHub Security Advisories on
<https://github.com/yorzi/ruby_llm-browser> ("Report a vulnerability"), or by email
to the maintainer listed in the gemspec. Please do not open a public issue for a
suspected vulnerability.

Include: affected version, a minimal reproduction, the impact you observed, and
whether secrets, cross-actor data, browser sessions or provider billing are involved.
We aim to acknowledge within a few days and to publish a fix and advisory once a
patch is available. Never include real credentials, cookies, `cdp_url` values or
private page payloads in a report; use synthetic fixtures.

## Security model in one page

- **Untrusted everything external.** Model output and page text are untrusted data.
  They can never change tool policy, grant permissions or authorize actions.
- **Default deny.** Only hosts you allow explicitly, over `http`/`https`, on approved
  ports, are reachable. Loopback, private, link-local, multicast and cloud-metadata
  addresses are rejected, including IPv6 and IPv4-mapped forms.
- **Fail closed on egress.** Ruby-side URL checks cannot prove what a *remote* browser
  does. `Policy#egress_qualified?` must be satisfied by the backend before a session
  starts; otherwise the Gem raises `UNSUPPORTED_SECURITY_CAPABILITY` and never
  contacts a provider.
- **Effectful retries are off.** Session creation, navigation, `act` and `end_` are
  issued with `max_retries: 0`. Unknown outcomes stay `unknown` /
  `cleanup_pending` and are never silently retried into a second session or a
  duplicated action.
- **Reduce secret exposure.** Credential-like fields, known secret literals and
  `cdp_url` endpoints are redacted; this is not a general PII/page-secret detector.
  Avoid authenticated/private browsing and raw payload logging. SDK client arguments are passed
  explicitly; the Gem never reads SDK environment defaults for credentials or base
  URLs, and refuses to start when `STAGEHAND_CUSTOM_HEADERS` is set unless the host
  approved it.
- **Live Act is disabled.** `RubyLLM::Browser::Act` is never registered by default,
  and the Engine refuses non-fake action backends. Offline single-use approval tests
  do not establish the missing same-session/target authorization protocol. Purchases,
  posting, account changes and access-control bypass remain unsupported.

## Scope of guarantees

Mocked or fake backends demonstrate the Gem's API logic only. They do not prove
provider-side network egress isolation, provider TTL enforcement or billing limits.
See `docs/SECURITY_MODEL.md` and `docs/SPEC_BASELINE.md` for the full, honest status.
