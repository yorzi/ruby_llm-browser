# 0.2.0 local candidate validation

This is the historical snapshot before publication. See [release verification](V0_2_RELEASE.md)
for the later remote CI, publication, artifact checksum, and stable documentation results.

2026-10-19 (Asia/Shanghai). Candidate source: `1222b71`. Implementation commits:
`d14df49` (verification foundation), `3705c6e` (tool factory), `d1069a9` (Doctor),
`1222b71` (candidate/package checks). Andy authorized local development and incremental
commits. Version 0.2.0 is an unreleased local candidate; public stable remains 0.1.0.
No push, tag, provider call, deployment, or publication occurred.

## Acceptance

| Requirement | Observed result |
| --- | --- |
| Read-only tool factory | Fresh Inspect/Extract instances share the explicit Context. Public RubyLLM registration and chat tool execution work on 2.0.0 and 2.1.1. No Act is added. |
| Host bindings and denial | Missing context/schema reject through existing constructors. Invalid schema contents and disallowed URLs reject before start. Extraction schema copies remain immutable. |
| Load boundary | Subprocesses confirm factory creation does not read provider configuration, dispatch, or load Rails/Stagehand. Offline Doctor does not load Stagehand or inspect provider environment. |
| Backend-aware diagnostics | Existing report fields remain; mode identifies offline/live/unconfigured. FakeBackend has no missing-provider warnings; custom backends avoid Stagehand checks. Unsupported Stagehand still fails. Mode is not qualification. |
| Agent validation loop | `bin/check`, separate browser bundle, one offline workbench, loopback server/driver probe, success/failure screenshots, package checks, and a generated-site link checker. No second application or task ledger. |
| Scope | No schema migration or runtime dependency change. Stagehand and live Act remain disabled. No 0.3 result-delivery work started. |

## Checks

Ruby 3.3.5, macOS arm64. SQLite 2.10.0; Stagehand 3.21.0. Database suites ran
sequentially. Browser fixtures use in-memory state; clean package checks use an empty
GEM_HOME outside the checkout and a private snapshot of the supplied gem.

| Check | Result |
| --- | --- |
| RubyLLM 2.1.1 / Active Record and Active Job 8.1.4 | 325 examples, 0 failures |
| RubyLLM 2.0.0 / Active Record and Active Job 8.1.4 | 325 examples, 0 failures |
| RubyLLM 2.0.0 / Active Record and Active Job 8.0.5.1 | 325 examples, 0 failures |
| RuboCop | 102 Ruby files, no offenses; 5 executable scripts checked separately, no offenses |
| Public examples | Plain-Ruby Inspect/Extract/denial/offline Doctor and Rails job/idempotency PASS |
| Chrome E2E | 4 examples, 0 failures: read-only tools, 390px keyboard recovery after denial, offline Doctor, unsupported Stagehand |
| Failure artifact probe | Exactly 1 intentional assertion failure; useful failed-page PNG inspected; source restored; all 4 scenarios rerun green |
| Clean installed artifact | `CORE_PACKAGE_PASS`, `RAILS_PACKAGE_PASS`; generated migration up/down PASS; entrypoint belongs to isolated GEM_HOME |
| Activated runtime audit | `CLEAN_RUNTIME_ADVISORIES_PASS`; resolved RubyLLM 2.1.1 and Stagehand 3.21.0 |
| Dependency audits | Root, RubyLLM 2.0, Rails 8.0, browser, and docs locks: no known advisories after refresh |
| Candidate metadata | `CANDIDATE_METADATA_PASS`, 88 packaged files; default release check intentionally refuses unreleased docs |
| Documentation | Stable v0.1.0 and working-tree next build PASS; 6,938 local HTML/asset links, zero broken; next identifies source 0.2.0 and stable 0.1.0 |
| Docs lint | 17 guides, zero errors. Six reviewed warnings: four GitHub-readable compatibility-link warnings, two expected candidate/latest-tag warnings |
| Workflow files | CI and release YAML parse; remote workflow execution NOT RUN |

Advisory database: `fa2295251efb3b0d1a300e5ce8ad700ff1f1b485`, 1,266 advisories.
This is a dated dependency check, not proof of no vulnerabilities.

Artifact: `pkg/ruby_llm-browser-0.2.0.gem` (ignored local build).
SHA-256: `c1fa04281b318494357d6aa6742a5d1f0f2351cc91ac4da0cbe878843e66a165`.
The clean-install verifier prints the hash before installation and tests a private copy,
so another build cannot replace its input. Current packaged source bytes match this
artifact. Development/browser fixtures, browser libraries, and this validation note
are excluded from the gem. Local evidence is excluded from the site too.

## Browser review

Capybara 3.40.0, Selenium 4.51.0, Puma 7.2.1, installed Chrome; explicit matching
local driver used. All servers and driver probes bind loopback. Ruby browser-test HTTP
clients permit loopback only; that guard is not a Chrome firewall or provider proof.

Artifacts (folder timestamps use UTC):

- Accepted run: `tmp/browser/20261018T232327-92610/` (four PNGs inspected).
- Intentional failure: `tmp/browser/20261018T232318-92612/`; offline Doctor's actual
  passing page is visible under the deliberately false assertion, not a blank tab.
- Manual IAB: `tmp/validation/manual-extraction.png`. Reviewed destination denial
  with zero starts, correction to an allowed URL, the extracted title and confirmed
  fake cleanup, keyboard-triggered offline diagnostics, and blocked Stagehand.
- What's New page reviewed in the local next site; navigation and code layout readable.

The workbench and documentation previews stopped, and temporary IAB tabs closed.
Chrome E2E sessions, drivers, and Puma processes ended. Screenshot artifacts are
synthetic local fixtures and remain ignored.

## Reproduce and next action

```sh
bin/check
CHROMEDRIVER=/path/to/matching/chromedriver bin/check-browser
bundle exec bundle-audit check --update
bin/check --package
bin/verify-release --candidate
docs/bin/build.sh
python3 scripts/check_docs_site.py
```

Logs are under ignored `tmp/validation/`. `factory-red.log` records the absent factory;
`doctor-red.log` records five failing backend-diagnostic expectations before the fix.
`candidate-check.log` includes all three suites and installed-package results.

Local 0.2 acceptance is complete. Ruby 3.2/3.4 and Linux remain configured in CI but
were not run locally; remote CI has not run for these commits. No PostgreSQL, live
provider qualification, external adoption, physical-device, or full accessibility audit
is claimed. To release, separately authorize a push, inspect exact remote CI, then
prepare dated changelog/release history and released metadata before authorizing a tag.
The release workflow never uses the candidate flag. Do not move v0.1.0 or start 0.3
as part of this work.
