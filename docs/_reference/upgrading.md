---
layout: default
title: Upgrading
nav_order: 2
description: Upgrade from 0.3.0 and configure verified local Stagehand executable identity for offline diagnostics.
---

# {{ page.title }}

{{ page.description }}

After reading this guide, you will know:

- How to update an application from 0.3.0.
- Why local binary diagnostics require a checksum.
- Which existing workflows stay supported.

## Upgrade from 0.3.0

Update your Gemfile and bundle:

```ruby
gem "ruby_llm-browser", "~> {{ site.version }}"
```

```sh
bundle update ruby_llm-browser
```

This release adds no runtime dependency or gem-managed database migration. Preserve
all operation, approval, and actor-lock rows. Do not rerun the install generator on
an existing installation. FakeBackend and opt-in Rails result delivery retain their
existing contracts.

## Supply Local Executable Identity

The local adapter no longer treats `STAGEHAND_SERVER_VERSION` or an unchecked
`STAGEHAND_SEA_BINARY` path as a binary pin. Configure an absolute executable path in
the SDK process environment and pass `server_binary_sha256:` with its host-approved
lowercase SHA-256 when constructing `StagehandBackend`.

The local binary diagnostic fails for missing, nonexecutable, changed, or mismatched
files. An injected `env:` must select the same path as the actual process environment.
The adapter checks current file bytes without executing the file. Obtain the expected
digest through your artifact review and protect the executable during use. See
[API and configuration]({% link _reference/api-and-configuration.md %}) for the full
contract. Remote diagnostics do not require this option.

Stagehand remains unsupported even when the binary check passes. Do not replace the
live qualification gate with a capability override. The new browser canaries calibrate
offline fixtures; they do not establish production isolation or cleanup.

## Earlier Versions

For upgrades from 0.2.0, first read the
[0.3.0 upgrading guide](https://github.com/yorzi/ruby_llm-browser/blob/v0.3.0/docs/_reference/upgrading.md)
for result delivery, immutable results, worker fencing, and delivery recovery.
For upgrades from 0.1.0, start with the
[0.2.0 upgrading guide](https://github.com/yorzi/ruby_llm-browser/blob/v0.2.0/docs/_reference/upgrading.md).
Preserve operation data and use additive migrations where required.

## Next Steps

- Read [What's New in 0.4]({% link _getting_started/whats-new-in-0-4.md %}).
- Review [local deployment feasibility]({% link _advanced/local-stagehand-deployment.md %})
  and [release history]({% link _reference/release-history.md %}).
