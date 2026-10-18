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

* What the local Doctor checks and what it cannot prove.
* Why backend egress isolation is an external host responsibility.
* Which live-provider and Act limitations are recorded for this project.

## Run a Local Diagnostic

`Doctor` checks local configuration without a network request or browser session. This
fake-backend example reports its exact boundary:

```ruby
require "ruby_llm/browser"

backend = RubyLLM::Browser::FakeBackend.new
puts RubyLLM::Browser::Doctor.new(backend: backend).report[:summary]
# => "configuration checks passed; live provider guarantees are not verified"
```

Passing the diagnostic means only that the inspected local settings pass. The backend
must assert enforced browser-side egress isolation before the Engine will start a live
session. That assertion does not configure or prove a provider firewall. Verify every
request path, including redirects, frames, popups, WebSockets, scripts, and subresources.

## Verify Provider Behavior Separately

Before considering live use, independently establish provider-side egress restrictions,
final URL reporting, session TTL and cleanup behavior, unknown-start recovery, and host
billing controls. The gem does not provide a browser firewall or a hard cost cap. The
Doctor does not call the provider and cannot establish these properties.

## Current Project Status

The repository's [release audit]({% link RELEASE_AUDIT.md %}) records no live provider qualification and marks the current source release as not ready for public publication or production claims. The audit also records that Act is simulation-only: the Engine refuses non-fake Act calls until same-session host approval and target binding are implemented.

Read-only tools do not dispatch browser actions. A page can still run scripts and initiate
requests, and returned page text remains untrusted data. Review the [security model]({% link SECURITY_MODEL.md %}) before designing a host deployment.

## Next Steps

* [Controlling source access]({% link _core_features/source-policy.md %}) - set host URL policy.
* [Running work in Rails]({% link _advanced/rails-integration.md %}) - protect durable jobs and recovery.
