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

* Why there is no public version-to-version upgrade path yet.
* Where to find migration steps for earlier development snapshots.
* What evidence must exist before a release tag is treated as supported.

## Public Releases

No public version has been released. The repository version constant is `0.1.0`, but
version metadata alone does not establish that the gem is available from RubyGems. The
release audit lists the provider, approval-protocol, and ownership gates that remain.

## Earlier Development Snapshots

If you ran an earlier development Rails generator, do not drop existing operation data
or rerun a create-table migration. Follow the additive migration instructions under
"Upgrading an earlier development snapshot" in the [Rails guide]({% link RAILS.md %}). Drain workers during the migration and do not reuse idempotency keys for legacy rows that lack request digests.

## Next Steps

* Review the [release history]({% link _reference/release-history.md %}) for version records.
* Review the [release audit]({% link RELEASE_AUDIT.md %}) before relying on a future release.
