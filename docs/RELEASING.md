---
layout: default
title: Compatibility and Release Checklist
description: Verify the package and release a version from its matching Git tag.
---

# Compatibility and release checklist

Build and verify the package before you publish a version. GitHub Actions releases the
gem from the matching version tag and deploys that version's documentation after success.

After reading this guide, you will know:

- Which combinations were exercised.
- How to run offline checks and build an artifact.
- Which evidence the automated release checks require.

## Compatibility evidence

The source repository's `docs/evidence/V0_3_VALIDATION.md` records local 0.3.0 checks.
`docs/evidence/V0_3_RELEASE.md` records the exact remote CI, published artifact and
hosted documentation results. The earlier audit below is historical evidence.

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
bundle exec ruby examples/rails_results.rb

BUNDLE_GEMFILE=gemfiles/ruby_llm_2_0.gemfile bundle install
BUNDLE_GEMFILE=gemfiles/ruby_llm_2_0.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/rails_8_0.gemfile bundle install
BUNDLE_GEMFILE=gemfiles/rails_8_0.gemfile bundle exec rspec

bundle exec rake build
bin/verify-release --candidate # for unreleased development candidates
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
- The built gem's `documentation_uri` points to the hosted documentation site.
- The optional Rails require loads on demand.
- The generated migration and all README-linked guides are shipped.
- All shipped examples run using the installed artifact.
- The artifact contains no keys, cookies, dumps, databases, lockfiles, or test fixtures.
- Dependency/license inventory and known-advisory check match the resolved versions.
- Record the artifact SHA-256, exact versions, commands and date in the candidate validation note.

## Release boundaries

The first-release scope is offline read-only. `FakeBackend` is the only built-in backend
supported for operations. `StagehandBackend` refuses live calls, its egress capability
stays unverified, and cleanup requests are disabled. The full live Act
protocol is deferred to a later version. No provider calls were run or authorized.

The owner selected version `0.1.0` for this package and instructed its release. H1 and
H2 approved the product handoff against exact Specs candidate Q
`22d488987517b10dcd96d2713ed3d47e8818b36b`; the candidate's historical version label is
`0.3.0-draft`. The later release instruction is separate from H2. See [the audit findings]({% link RELEASE_AUDIT.md %}) for the live-provider limits.

Keep Stagehand unsupported and live Act disabled. Before enabling either in a later
version, qualify egress across every request path, final URL reporting, TTL, cleanup
status, unknown-start recovery, and provider billing controls. No live provider call was
made for `0.1.0`.

## Releasing a version

For a later version, update the gem version in `lib/ruby_llm/browser/version.rb` and the
documentation version in `docs/_config.yml` to the same value. Keep `released: false`
while preparing a candidate. Set it to `true` and update `stable_version` when the
owner authorizes a release. The documentation builder uses release tags
for the stable site and builds the working tree under `/next/`. Add a matching release
entry to `CHANGELOG.md` and `docs/_reference/release-history.md`.

During candidate development, keep changes under `Unreleased` in the changelog and
run `bin/verify-release --candidate`. Before tagging, move them to a dated release
section and run `bin/verify-release` without that flag. The tag workflow requires
released metadata; local candidate verification cannot enable publication.

Run the checks above, review the package contents and push the completed commit to
`main`. Then create and push a matching tag, for example `v{{ site.version }}` for gem version
`{{ site.version }}`:

```bash
git tag -a v{{ site.version }} -m "Release {{ site.version }}"
git push origin v{{ site.version }}
```

The `Release Gem` workflow rejects a tag that does not match both the gem and docs
versions, or has no matching changelog section. It runs the suite, dependency audit and
isolated package verification before RubyGems publishing through OIDC trusted publishing.
On success it creates a GitHub Release with the gem, checksum and matching changelog
section. The Docs workflow then builds the tagged stable docs plus current `main` docs.
Configure the matching
pending trusted publisher on RubyGems with owner `yorzi`, repository `ruby_llm-browser`,
workflow `release.yml`, and environment `release` before the first tag.

## Next steps

- Review the requirement evidence in the source repository's `docs/WORK.md` and the [remaining audit findings]({% link RELEASE_AUDIT.md %}).
- Follow the [roadmap to 1.0]({% link _reference/roadmap.md %}) for proposed version scope.
  The source repository's `docs/RELEASE_ACTION_PLAN.md` preserves the 0.1.0 release record.
