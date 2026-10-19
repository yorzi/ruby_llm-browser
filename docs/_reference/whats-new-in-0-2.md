---
layout: default
title: What's New in 0.2
parent: Release History
nav_order: 1
description: Use the read-only tool factory and backend-aware diagnostics in this release.
---

# {{ page.title }}

{{ page.description }}

After reading this guide, you will know:

- How to register the read-only tool pair.
- How to distinguish offline diagnostics from live-backend checks.
- Where to verify changes locally before upgrading.

## Read-only Tool Factory

You can register the read-only tools in one call:

```ruby
chat.with_tools(*RubyLLM::Browser.tools(context: context, schema: schema))
```

The host still supplies context and schema. The factory returns Inspect and Extract
instances and never registers Act. Individual constructors remain supported. Read
[Inspecting and extracting]({% link _core_features/inspect-extract.md %}) for a complete
offline example and the validation behavior.

## Backend-aware Diagnostics

Doctor adds a `mode` field while preserving `ok`, `summary`, and `checks`. FakeBackend
reports `offline` mode and skips provider environment and SDK checks. Stagehand
reports `live` mode and remains blocked. Custom backends no longer receive unrelated
Stagehand warnings. Read [Checking Configuration]({% link _core_features/diagnostics.md %}).

## Development Verification

Use `bin/check` for offline contracts, lint, alternate bundles, and examples. Use
`bin/check-browser` for desktop/mobile workflows and fixture screenshots. The
[development guide]({% link _advanced/development-and-testing.md %}) explains setup,
package verification, and the limits of this evidence.

Stagehand and live Act remain unsupported. This release remains offline-only.
