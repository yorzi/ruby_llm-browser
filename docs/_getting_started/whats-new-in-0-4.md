---
layout: default
title: What's New in 0.4
redirect_from:
  - /whats-new/
nav_order: 4
description: Verify local Stagehand executable identity and calibrate offline browser tests in the 0.4.4 release.
---

# {{ page.title }}

{{ page.description }}

After reading this guide, you will know:

- How local executable identity checks change.
- How to run the pinned SDK and browser fixtures.
- Which live-deployment requirements remain incomplete.

## Verify the Local Executable

Version 0.4.4 requires a host-approved checksum for local diagnostics:

```ruby
backend = RubyLLM::Browser::StagehandBackend.new(
  browserbase_api_key: "diagnostic-placeholder",
  model_api_key: "diagnostic-placeholder",
  model_name: "diagnostic-model",
  server: :local,
  server_binary_sha256: reviewed_sha256
)
report = RubyLLM::Browser::Doctor.new(backend: backend).report
```

Set `STAGEHAND_SEA_BINARY` in the process environment to the absolute path of the
reviewed executable. `reviewed_sha256` is its host-approved lowercase SHA-256. The
diagnostic reads the file without running it. A missing, nonexecutable, changed, or
mismatched file fails the binary check. A version label or unchecked path is no
longer accepted as a pin. The SDK can otherwise use an existing cache or download
a server binary. See [API and configuration]({% link _reference/api-and-configuration.md %}).

The placeholders above are for diagnostics only. A passing executable check does
not enable live calls. Doctor still reports Stagehand as unsupported.

## Calibrate the Offline Fixtures

From the source checkout, install the development bundle and run:

```sh
BUNDLE_GEMFILE=gemfiles/local_stagehand.gemfile bundle install
bin/check-local-stagehand
```

The runner pins Ruby SDK 3.21.0 and tests its HTTP serializer without starting
Stagehand. Chrome canaries cover redirects, fetch, images, scripts, frames, popups,
Worker fetch, and WebSocket upgrade requests. Same-origin and cross-origin controls
confirm that requests actually arrive. A partial-denial control blocks only the image.
The runner retains screenshots and request receipts with `qualified: false`.

Read [Local Stagehand feasibility]({% link _advanced/local-stagehand-deployment.md %})
for setup, coverage, and gaps. `bin/check-browser --network` and browser CI also run
the canary calibration. These tools and dependencies are development-only.

## Find the Documentation from RubyGems

The gem's `documentation_uri` now points to the hosted documentation site. The
packaged guides and examples remain available as Markdown. Runtime dependencies
and the Rails database schema do not change in this release.

## Live Support Remains Incomplete

Version 0.4.4 supports offline operations through FakeBackend. It does not complete
the original live-deployment milestone. Enforced browser egress, connection-time
DNS/IP checks, an independent lifecycle supervisor, expiry, and confirmed cleanup
still need deployment-specific evidence. Stagehand and live Act remain disabled.
No real provider calls or live billing qualification form part of this release.

## Next Steps

- Follow [Upgrading]({% link _reference/upgrading.md %}) for the local diagnostic change.
- Review [the roadmap]({% link _reference/roadmap.md %}) before preparing live tests.
