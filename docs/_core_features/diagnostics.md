---
layout: default
title: Checking Configuration
nav_order: 5
description: Diagnose the configured backend without opening a session or making a provider request.
---

# {{ page.title }}

{{ page.description }}

After reading this guide, you will know:

- How to check offline configuration without provider credentials.
- Which checks apply to each backend.
- Why a local pass cannot qualify a live deployment.

## Check an Offline Backend

```ruby
require "ruby_llm/browser"

report = RubyLLM::Browser::Doctor.new(backend: RubyLLM::Browser::FakeBackend.new).report
puts report[:mode] # => offline
puts report[:ok]   # => true
puts report[:summary]
# => configuration checks passed; live provider guarantees are not verified
```

Doctor checks RubyLLM compatibility and the fake backend's capabilities. It does not
load the Stagehand SDK, inspect provider credentials or endpoint overrides, or open a
session. You do not need provider credentials to run offline checks.

## Interpret the Report

Use `ok` to decide whether configuration checks passed. Use `mode` to identify which
backend the report describes, not whether that backend is supported. The existing
`summary` and `checks` fields remain available. Each check has `name`, `status`, and
`detail`; statuses are `pass`, `warn`, `info`, or `fail`. Any failure makes `ok` false.

| Mode | Meaning | Checks |
| --- | --- | --- |
| `offline` | FakeBackend with fake server mode | RubyLLM and backend capabilities; no provider environment or SDK checks |
| `live` | Stagehand or another non-offline backend | RubyLLM and backend capabilities; Stagehand also checks its SDK and environment |
| `unconfigured` | No backend supplied | RubyLLM and a failed backend/egress check |

A custom backend does not depend on Stagehand diagnostics. Its capability checks
still enforce unverified egress, an unpinned local server, and unapproved custom-header
capabilities as failures. A backend's enforced-egress assertion is not independent
evidence of its deployment behavior.

## Diagnose Stagehand Without Calling It

Pass your host-created Stagehand backend to `Doctor.new(backend:)`. It reports `live`
mode and a failed `egress_isolation` check because the built-in adapter is unsupported.
Having an installed SDK or environment credentials cannot enable live operations.

Stagehand diagnostics report the SDK version, endpoint override names, and credential
presence in the supplied environment without printing values. These observations do
not configure the backend or replace explicit constructor credentials. Doctor never
calls the provider to test credentials, billing, egress, or session cleanup.

## Next Steps

- Read [live-backend qualification]({% link _advanced/live-backend-qualification.md %})
  for the deployment evidence needed before live use.
- Use [development and testing]({% link _advanced/development-and-testing.md %}) to
  exercise diagnostics in the offline browser workbench.
