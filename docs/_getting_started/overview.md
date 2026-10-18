---
layout: default
title: How RubyLLM::Browser Works
nav_order: 2
description: See how trusted host inputs, tools, policy, backends, and operation stores fit together.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* Which objects the host creates and which inputs the model can supply.
* How a tool call moves through policy checks and the backend.
* Which result and lifecycle guarantees the gem provides.

## The Public API

The host creates a `Context` for an authenticated actor and run. It supplies the backend,
source policy, operation store, optional approval store, and budget. The model does not
choose those objects.

`Inspect` observes an allowlisted page. `Extract` reads fields using a schema fixed by
the host when the tool is constructed. The tools return hashes that RubyLLM can pass to
the model. Direct calls to `Engine#inspect` and `Engine#extract` return a `Result` object.

## How It Fits Together

The Engine checks the destination and backend capability before a session starts. It
reserves and updates an operation, tracks time, steps, and retained bytes, then asks the
backend to navigate and observe or extract. The Engine attempts session cleanup before
it returns. If the remote outcome or cleanup cannot be confirmed, the operation remains
`unknown` or `cleanup_pending`; it is not treated as a successful result.

`Policy` controls URL destinations, extraction schemas, output limits, and the restricted
Act simulation. `FakeBackend` runs without network access. `StagehandBackend` adapts the
Stagehand Ruby SDK, but the host must establish browser-side egress isolation separately.
In-memory stores are useful for a single process and offline examples; use the Rails
adapter or another durable store when work must survive restarts or worker changes.

The output is evidence with provenance, not a verified statement of fact. Page content
can be adversarial and can initiate requests inside the remote browser even when the gem
does not click or submit forms.

## Next Steps

* [Getting Started]({% link _getting_started/getting-started.md %}) - install and run the offline example.
* [Configuration]({% link _getting_started/configuration.md %}) - choose host-owned defaults.
* [API and configuration reference]({% link _reference/api-reference.md %}) - see options, statuses, and result fields.
