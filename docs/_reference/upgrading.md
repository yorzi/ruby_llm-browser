---
layout: default
title: Upgrading
nav_order: 2
description: Check the supported upgrade path before moving a RubyLLM::Browser application to a new version.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* What changed in the first public release.
* Where to find migration steps for earlier development snapshots.
* What evidence must exist before a release tag is treated as supported.

## Public Releases

Version `{{ site.version }}` is the first public release. It has no earlier public version
to migrate from. Install it with `bundle add ruby_llm-browser --version "~> {{ site.version }}"`.

## Earlier Development Snapshots

If you ran an earlier development Rails generator, do not drop existing operation data
or rerun a create-table migration. Follow the additive migration instructions under
"Upgrading an earlier development snapshot" in the [Rails guide]({% link RAILS.md %}). Drain workers during the migration and do not reuse idempotency keys for legacy rows that lack request digests.

## Next Steps

* Review the [release history]({% link _reference/release-history.md %}) for version records.
* Review the [release audit]({% link RELEASE_AUDIT.md %}) before enabling a live backend.
