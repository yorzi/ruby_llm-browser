---
layout: default
title: Qualifying a live backend
nav_order: 2
description: Review the host and provider guarantees required before a live browser session.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* Why `StagehandBackend` is unsupported in the first release.
* Which egress and cleanup controls need qualification before live use.
* Why the full live Act protocol is deferred to a later version.

## Run a Local Diagnostic

`Doctor` checks local configuration without a network request or browser session. This
fake-backend example reports its exact boundary:

```ruby
require "ruby_llm/browser"

backend = RubyLLM::Browser::FakeBackend.new
puts RubyLLM::Browser::Doctor.new(backend: backend).report[:summary]
# => "configuration checks passed; live provider guarantees are not verified"
```

The diagnostic is local and makes no provider request. In this release it reports the
built-in Stagehand backend as unsupported: `egress_isolation` remains `:unverified`, and
the Engine refuses to start a session. The host cannot override this status with a
constructor option. A custom backend must enforce its own browser-side network boundary.

The fake report has `mode: :offline` and skips provider credential and SDK checks.
Stagehand reports `mode: :live` even though it remains unsupported; mode describes
the backend, not its qualification. See [Checking Configuration]({% link _core_features/diagnostics.md %})
for the report fields and checks applied to each backend.

Browserbase's documented [Allowed Domains feature](https://docs.browserbase.com/platform/browser/security/allowed-domains)
applies to top-frame navigations. It does not block iframe or subresource requests such
as scripts, images, and XHR. That setting alone cannot qualify provider egress. Any future
deployment must separately verify DNS at connection time, redirects, frames, popups,
WebSockets, scripts, and all other request paths.

## Verify Provider Behavior Separately

Before considering live use, independently establish provider-side egress restrictions,
final URL reporting, session TTL, unknown-start recovery, billing controls, and confirmed
cleanup. The gem does not provide a browser firewall or a hard cost cap. The Doctor does
not call the provider and cannot establish these properties.

Cleanup needs a status check. Stagehand 3.21's `SessionEndResponse.success` reports that
the end request succeeded; it does not report the session's final status. Browserbase's
[`REQUEST_RELEASE` endpoint](https://docs.browserbase.com/reference/api/update-a-session)
requests completion and may return a session still marked `PENDING`. The
[`Get a Session` endpoint](https://docs.browserbase.com/reference/api/get-a-session)
exposes status and `endedAt`, but the Stagehand Ruby SDK does not expose that lookup.
The adapter cannot start a live session in this release. Its `end_session` method returns
`false` without calling the SDK. An operation whose cleanup is not confirmed stays
`cleanup_pending`; the Gem does not claim terminal cleanup.

## Current Project Status

The repository's [release audit]({% link RELEASE_AUDIT.md %}) records no live provider
qualification and marks the built-in Stagehand backend unsupported. The first release
uses read-only tools; the full live Act protocol is deferred to a later version. The
Engine refuses non-fake Act calls until same-session host approval and target binding are
implemented.

Read-only tools do not dispatch browser actions. A page can still run scripts and initiate
requests, and returned page text remains untrusted data. Review the [security model]({% link SECURITY_MODEL.md %}) before designing a host deployment.

## Next Steps

* [Local Stagehand feasibility]({% link _advanced/local-stagehand-deployment.md %}) - run pinned SDK contracts and loopback canaries without a provider.
* [Controlling source access]({% link _core_features/source-policy.md %}) - set host URL policy.
* [Running work in Rails]({% link _advanced/rails-integration.md %}) - protect durable jobs and recovery.
