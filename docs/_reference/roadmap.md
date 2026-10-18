---
layout: default
title: Roadmap to 1.0
nav_order: 8
description: Plan small releases toward a reliable read-only browser integration for RubyLLM.
---

# {{ page.title }}

{{ page.description }}

After reading this guide, you will know:

- What works today and what still blocks practical live use.
- Which small features belong in the next release.
- What must pass before the project releases 1.0.0.

## Start with a Narrow 1.0

The proposed 1.0 supports one complete workflow: your RubyLLM application inspects an
approved public page or extracts schema-checked data, receives a bounded result with
provenance, and can account for the browser session through cleanup. It works in plain
Ruby and through the optional Rails adapter.

Version 0.1.0 provides the offline foundation: Inspect, Extract, URL policy, bounded
results, operation bookkeeping, Rails jobs, and Act simulation. It does not provide a
supported live backend. The current Stagehand adapter refuses live operations. Rails
jobs track state but do not durably deliver result bodies.

**This is a proposed development sequence, not a list of available features or release
dates.** Future API names below are proposals. Keep each release small; use patch
releases for fixes and split a milestone if implementation reveals a larger change.

## Release Sequence

Build convenience on the current offline API first. Complete the Rails result path
next. Qualify one live deployment before advertising browser support, then use pilot
feedback to settle the public API.

| Version | Outcome | Release condition |
| --- | --- | --- |
| 0.2.0 | Easier tool setup and clearer offline diagnostics | Two additive features, tested with no provider requests |
| 0.3.0 | Usable Rails result delivery | A host can retrieve a job's result after the worker exits |
| 0.4.0 | One supported live read-only deployment | Egress, final URL, session expiry and cleanup qualified on that deployment |
| 0.5.0 | Pilot feedback and recovery hardening | Plain-Ruby and Rails workflows exercised outside the test suite |
| 1.0.0-rc.1 | Stable API candidate | Feature freeze, complete upgrade instructions, candidate package verified |
| 1.0.0 | Supported read-only integration | All acceptance criteria below pass on the release candidate |

### 0.2.0: Two Small Features

The current local source implements both features below. Version `0.2.0` remains an
unreleased candidate; stable users stay on `0.1.0`. See
[What's New]({% link _getting_started/whats-new.md %}) for usage and
[development and testing]({% link _advanced/development-and-testing.md %}) for validation.

1. Add the read-only tool factory `RubyLLM::Browser.tools(context:, schema:)`.
   Return Inspect and Extract instances suitable for `chat.with_tools(*tools)`. Keep
   the context and extraction schema explicit; never include Act. Reuse the existing
   constructors and validation instead of creating a second configuration API.
2. Make Doctor distinguish offline and live-backend checks. FakeBackend diagnostics
   should not warn that provider credentials are missing. Live-backend reports must
   keep the unsupported Stagehand reason visible. Preserve the structured report and
   make clear that a passing local check does not qualify a provider.

Acceptance: exercise the factory through RubyLLM's public tool-registration API on
both supported RubyLLM versions; reject an invalid schema; verify no Act registration,
provider request, credential discovery, or Rails load. Test Doctor with fake and
unsupported live backends. Update the relevant guides and changelog with the features.

Do not add a CLI, a context builder, new database tables, or live support in this slice.
The factory and Doctor are implemented in separate commits. Candidate validation
precedes any separately authorized push, tag, or publication.

### 0.3.0: Complete the Rails Result Path

Add an opt-in result-delivery hook that lets the host persist the sanitized `Result`
against its operation ID. Provide a runnable host example that stores and retrieves
the result after an asynchronous job finishes. The host owns access checks, retention,
and storage; the gem does not need an admin interface or a general results database.

Acceptance: retrieve a schema-checked extraction after worker exit; refuse cross-actor
reads in the host example; handle success, truncation, failure, and pending cleanup.
A delivery failure must be visible and must never cause the browser operation to run
again. Document delivery semantics, duplicate handling, and recovery separately from
the operation's session state. Verify generator upgrades preserve existing records.

### 0.4.0: Qualify One Live Read-only Deployment

Begin with a feasibility check of the pinned SDK and a named deployment. Determine
whether the deployment can enforce every required browser request boundary and report
verified final URLs and terminal session state. Implement only the missing adapter
integration needed for that deployment. Keep live Act disabled.

Acceptance requires deployment-specific evidence for redirects, subresources, frames,
popups, WebSockets, connection-time DNS/IP restrictions, final URLs, session expiry,
and confirmed cleanup. Exercise timeouts, worker death, and lost start responses with
controlled fixtures. Unknown sessions retain quota and have an explicit host review
path; an SDK acknowledgement alone cannot release them.

Prepare the fixtures and opt-in qualification runner offline first. Live runs require
separate owner authorization for the deployment, data, and spending. Keep default CI
offline. Report provider billing controls separately from the advisory cost field.

If the deployment cannot meet the required controls, stop this milestone and record
the gap. Keep live support disabled. Do not replace qualification with a boolean flag
or promote an offline-only package to 1.0 under this plan.

### 0.5.0: Exercise Real Application Workflows

Run two authorized pilots: a plain-Ruby extraction and a Rails background extraction
with durable host result retrieval. Record the exact dependency/deployment versions,
fixture expectations, observed results, failures, and cleanup outcomes. A controlled
host application is sufficient; customer adoption is not a release prerequisite.

Use pilot findings to improve errors, delivery, cancellation, and recovery. Confirm
that duplicate jobs do not repeat provider starts, unknown outcomes remain visible,
and result limits and redaction behave as documented. Resolve public API changes now
and provide migrations before freezing the API.

### 1.0.0-rc.1: Freeze and Verify

Freeze tool constructors, factory arguments, result fields, error codes, backend/store
contracts, and Rails schema/delivery hooks. Publish migration instructions for every
breaking pre-1.0 change. Run the declared Ruby/RubyLLM/Rails matrix, build the gem,
install the actual artifact in a clean environment, and verify its shipped examples,
generator, guides, and dependency audit.

Repeat the live qualification against the candidate's exact artifact and deployment.
Fix defects through further release candidates. Feature requests return to a later
minor release. A candidate with an unresolved blocker does not advance to 1.0.0.

## 1.0.0 Acceptance Criteria

- **Useful:** both pilot workflows complete, and one named live read-only deployment
  is supported with reproducible evidence and documented limits.
- **Controlled:** URL policy, schema validation, result bounds, and redaction pass
  positive and denial cases. Deployment qualification covers all browser request paths.
- **Recoverable:** cancellation, duplicate jobs, worker death, unknown starts, and
  pending cleanup preserve correct state and quota. Host recovery steps are tested.
- **Retrievable:** a Rails host can persist and authorize result retrieval after a job
  exits. Delivery failure cannot trigger a repeated browser action.
- **Stable:** the public API and database upgrade path are documented and covered by
  compatibility checks. Unsupported databases and backends are identified explicitly.
- **Distributable:** the release artifact passes the compatibility matrix, clean
  installation, examples, documentation build, and dependency checks. Version, tag,
  changelog, and stable documentation agree. The owner authorizes publication.

Live Act, multiple providers, PostgreSQL qualification, authenticated browsing,
screenshots, downloads, arbitrary JavaScript, a hosted UI, and a cost ledger are not
required for this 1.0. Keep unsupported capabilities explicit. Consider live Act only
as a separate feature with same-session approval and target identity guarantees.

## Keep Planning and Documentation Separate

The README introduces the project. Site guides teach supported behavior and provide
the API reference. This page owns future scope; the changelog records shipped changes.
Historical release audits remain evidence for their exact versions, not a current
task queue. Plan changes do not rewrite the approved specification baseline.

Read [API and configuration]({% link _reference/api-and-configuration.md %}),
[Rails jobs and recovery]({% link _advanced/rails-integration.md %}), and
[live-backend qualification]({% link _advanced/live-backend-qualification.md %}) for
the current contracts. Follow [the release checklist]({% link RELEASING.md %}) when a
milestone is ready to ship.
