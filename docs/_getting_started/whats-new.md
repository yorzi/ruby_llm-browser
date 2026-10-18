---
layout: default
title: What's New
nav_order: 4
description: Review the current development changes before updating an application.
---

# {{ page.title }}

{{ page.description }}

After reading this guide, you will know:

- How to register the read-only tool pair.
- Where to verify changes locally before upgrading.

## Read-only Tool Factory

The current development version adds a short registration path:

```ruby
chat.with_tools(*RubyLLM::Browser.tools(context: context, schema: schema))
```

The host still supplies context and schema. The factory returns Inspect and Extract
instances and never registers Act. Individual constructors remain supported. Read
[Inspecting and extracting]({% link _core_features/inspect-extract.md %}) for a complete
offline example and the validation behavior.

## Development Verification

Use `bin/check` for offline contracts, lint, alternate bundles, and examples. Use
`bin/check-browser` for desktop/mobile workflows and fixture screenshots. The
[development guide]({% link _advanced/development-and-testing.md %}) explains setup,
package verification, and the limits of this evidence.

These are unreleased source changes. Stagehand and live Act remain unsupported.
