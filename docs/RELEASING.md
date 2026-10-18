---
layout: default
title: Compatibility and Release Checklist
description: Verify the exact artifact and resolve release gates before requesting publication.
---

# Compatibility and release checklist

Verify the exact artifact and resolve the release gates before requesting publication.

After reading this guide, you will know:

- Which combinations were exercised.
- How to run offline checks and build an artifact.
- Which approvals and provider evidence are still required.

## Compatibility evidence

The 2026-10-18 audit runs on Ruby **3.3.5**, arm64 macOS, with Stagehand **3.21.0**,
JSONSchemer **2.5.0**, and sqlite3 **2.10.0**. Full offline suites cover:

| RubyLLM | Active Record / Active Job | Result |
| --- | --- | --- |
| 2.1.1 | 8.1.4 | PASS |
| 2.0.0 | 8.1.4 | PASS |
| 2.0.0 | 8.0.5.1 | PASS |

The expanded CI configuration includes Ruby 3.2/3.3/3.4 and RubyLLM 2.0.0/2.1.1,
plus Rails 8.0. All seven compatibility jobs and the build/install/advisory job passed
for commit `0ec34d4` in [this CI run](https://github.com/yorzi/ruby_llm-browser/actions/runs/39086570934).
Do not treat that run as evidence for later code changes or live provider guarantees.
Rails 7 and MySQL are not supported targets. PostgreSQL must be tested separately.

## Running checks

```bash
bundle install
bundle exec rake
bundle exec bundle-audit check --update
bundle exec ruby examples/plain_ruby.rb
bundle exec ruby examples/rails_adapter.rb

BUNDLE_GEMFILE=gemfiles/ruby_llm_2_0.gemfile bundle install
BUNDLE_GEMFILE=gemfiles/ruby_llm_2_0.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/rails_8_0.gemfile bundle install
BUNDLE_GEMFILE=gemfiles/rails_8_0.gemfile bundle exec rspec

bundle exec rake build
bundle exec ruby bin/verify-package --rails --audit
```

The default suite blocks unmocked network calls. HTTP contract tests use the actual
Stagehand client/serializers with stubbed HTTP, not paid browser sessions. Generator
tests resolve the documented Rails namespace and migrate the generated schema up/down.
Documentation/package tests check local links, shipped guides/examples and executable
offline README examples. These are bounded engineering checks, not a penetration test.

## Verifying the built gem

Use a fresh temporary directory for every install. Install the built gem there, then
activate it from outside the checkout. Confirm its loaded entrypoint lives under that
GEM_HOME, not under the source tree. Do not use `--ignore-dependencies` to claim that
dependency resolution succeeded. A clean network-resolved install is stronger evidence
than an install that borrows the developer's existing dependencies.

`bin/verify-package` installs without `--ignore-dependencies`, activates the artifact
outside the checkout, runs shipped examples, and optionally installs Rails and tests
the shipped generator/migration. `--audit` checks the actually activated core runtime
gems against the advisory database refreshed by `bundle-audit check --update`. This
catches default gems that a development lockfile may omit. Logs and a JSON version
inventory are retained in the temporary evidence directory printed by the command.

Verify all of the following:

- Core require loads no Rails, Active Record, Active Job, or Stagehand client.
- The optional Rails require loads on demand.
- The generated migration and all README-linked guides are shipped.
- Both examples run using the installed artifact.
- The artifact contains no keys, cookies, dumps, databases, lockfiles, or test fixtures.
- Dependency/license inventory and known-advisory check match the resolved versions.
- Record the artifact SHA-256, exact versions, commands and date in the WORK ledger.

## Publication gates

The first-release scope is offline read-only. `FakeBackend` is the only built-in backend
supported for operations. `StagehandBackend` refuses live calls, its egress capability
stays unverified, and cleanup requests are disabled. The full live Act
protocol is deferred to a later version. No provider calls were run or authorized.

**Publication is on hold** until the independent H1 review, owner H2 approval, naming and
license decisions, and exact-artifact review are complete. See [the audit findings]({% link RELEASE_AUDIT.md %}).

1. Keep Stagehand and live Act unsupported in this release. Before enabling either in a
   later version, qualify egress across every request path, final URL reporting, TTL,
   cleanup status, unknown-start recovery, and provider billing controls. This requires a
   separately authorized live qualification; no such call was made for this release.
2. Complete an independent H1 review, generate and freshness-check the human HTML, and
   obtain the owner's H2 approval against the fixed review question and candidate commit.
3. Confirm RubyGems account/name ownership and naming/affiliation clearance. A 404 for
   an unregistered name does not reserve it or establish permission to use it.
4. Complete the distribution license review. The resolved metadata inventory and pinned
   Stagehand MIT text in NOTICE are evidence, not legal/name clearance.
5. Run expanded remote CI, review the final diff and exact artifact, and publish only
   after the outstanding gates pass.

Keep the changelog under **Unreleased** until publication. Building version `0.1.0` is
not proof a `0.1.0` release exists. This checklist does not create a tag, push commits,
change repository visibility, or invoke RubyGems publication.

## Next steps

- Review the requirement evidence in the source repository's `docs/WORK.md` and the [remaining audit findings]({% link RELEASE_AUDIT.md %}).
- Follow the source repository's `docs/RELEASE_ACTION_PLAN.md` for the selected scope and
  the remaining review and distribution gates.
