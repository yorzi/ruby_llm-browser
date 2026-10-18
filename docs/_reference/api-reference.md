---
layout: default
title: API Reference
nav_order: 4
guide: false
description: Find the RubyLLM::Browser classes for tools, policy, results, backends, and Rails jobs.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

The [generated RDoc reference]({{ '/api/' | relative_url }}) documents classes and public methods from the Ruby source. Start with the task you need to perform:

| Task | Public API |
| --- | --- |
| Build trusted inputs for an operation | `Context`, `Policy`, `Budget` |
| Inspect a page or extract structured data | `Inspect`, `Extract`, `Engine` |
| Simulate one host-approved action offline | `Act`, `Approval`, `ApprovalStore` |
| Read a bounded result | `Result` |
| Use an offline backend | `FakeBackend` |
| Adapt the Stagehand Ruby SDK | `StagehandBackend`, `Capabilities`, `Doctor` |
| Persist operation or approval state | `OperationStore`, `ApprovalStore` and their implementations |
| Run Rails background jobs and cleanup | `RubyLLM::Browser::Rails::OperationJob`, `Reaper` |

Start with [Getting Started]({% link _getting_started/getting-started.md %}) for a runnable offline example. The [API and configuration guide]({% link _reference/api-and-configuration.md %}) explains inputs, results, limits, and errors.

The reference is generated from source comments. Build it locally with `docs/bin/build-api.sh tmp/api`.
