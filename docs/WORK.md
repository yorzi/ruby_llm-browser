---
layout: default
title: WORK Ledger
description: Track requirement evidence with exact fixtures, commands, dependency versions, and limits.
llms: false
---

# WORK ledger

The implementation repository owns this ledger. Each functional requirement records the
test ID, exact dependency versions, run command, fixture, result and date. The rule is
simple: `NOT RUN` is written as `NOT RUN`, never as `PASS`.

## Environment used for local runs

| Field | Value |
| --- | --- |
| Ruby | 3.3.5 (arm64-darwin) |
| RubyLLM | 2.1.1 |
| Stagehand | 3.21.0 (development only; never called live) |
| Rails / Active Job | active_record 8.1.4 + active_job 8.1.4, in-memory SQLite (adapter now exercised) |
| Command | `bundle exec rspec` and `bundle exec rubocop` |

## Progress slices (S0 → S4)

| Slice | Deliverable | State |
| --- | --- | --- |
| S0 | Bootstrap: gemspec, version, Ruby-only fixture, CI, OSS docs, baseline record | DONE |
| S1 | Read-only `Inspect`/`Extract` core with fake backend, policy, bounded results | DONE |
| S2 | Stagehand adapter, durable operation store, quotas, TTL/reaper, reconciliation | PARTIAL: hardened offline; live egress/final-URL/TTL and unknown-start correlation unqualified |
| S3 | Opt-in `Act` with one-use approvals, Rails 8 jobs, cancellation, negative tests | PARTIAL: read-only Rails jobs tested; Act simulation only, live same-session protocol missing |
| S4 | Full matrix, clean install, security/compat/license docs, human-approved release | PARTIAL (Gem builds and clean-installs; compatibility matrix + public release pending) |

## Functional-requirement evidence

All rows start as `NOT RUN` and are filled in as tests land. Columns: test file(s), run
command, result, date. Every `PASS` below is a **fake-backend / offline** result; no row
proves remote browser egress and no live Stagehand call has been run.

| FR | Positive | Denial / fault | Result | Date |
| --- | --- | --- | --- | --- |
| FR-01 Tool + configuration | `spec/ruby_llm/browser/inspect_spec.rb`, `spec/ruby_llm/browser/extract_spec.rb`, `spec/ruby_llm/browser/context_spec.rb` | `spec/ruby_llm/browser/inspect_spec.rb`, `spec/ruby_llm/browser/extract_spec.rb`, `spec/integration/require_spec.rb` | PASS (fake, no Rails) | 2026-10-17 |
| FR-02 session/operation | `spec/ruby_llm/browser/engine_spec.rb`, `spec/ruby_llm/browser/fake_backend_spec.rb` | `spec/ruby_llm/browser/engine_spec.rb`, `spec/ruby_llm/browser/in_memory_operation_store_spec.rb` | PASS (fake lifecycle); live Stagehand NOT RUN | 2026-10-17 |
| FR-03 read-only inspect | `spec/ruby_llm/browser/engine_spec.rb`, `spec/security/url_guard_spec.rb` | `spec/ruby_llm/browser/engine_spec.rb`, `spec/security/url_guard_spec.rb` | PASS (policy/engine); remote-browser egress NOT RUN | 2026-10-17 |
| FR-04 structured extract | `spec/ruby_llm/browser/extract_spec.rb`, `spec/ruby_llm/browser/engine_spec.rb` | same | PASS (fake) | 2026-10-17 |
| FR-05 approved Act | `spec/ruby_llm/browser/act_spec.rb`, `spec/ruby_llm/browser/engine_spec.rb` | same, `spec/security/release_audit_spec.rb` | PASS for simulation only; live Act refused, complete same-session protocol NOT IMPLEMENTED | 2026-10-18 |
| FR-06 Rails jobs | `spec/rails/operation_job_spec.rb`, `spec/rails/reaper_spec.rb`, `spec/rails/active_record_operation_store_spec.rb`, `spec/rails/active_record_approval_store_spec.rb` | same (wrong actor, fenced-out worker, cancel-mid-session, cleanup_pending visible) | PASS (fake backend + in-memory SQLite) | 2026-10-17 |
| FR-07 failure/budget/audit | `spec/ruby_llm/browser/engine_spec.rb` (budget, redaction), `spec/ruby_llm/browser/stagehand_backend_spec.rb` | `spec/ruby_llm/browser/stagehand_backend_spec.rb` (env override, SDK retry off, `cdp_url`), `spec/ruby_llm/browser/doctor_spec.rb` | PASS (offline); live Stagehand NOT RUN | 2026-10-17 |
| FR-08 full delivery | Build/install evidence below, `spec/integration/documentation_spec.rb` | Core/Rails require, generator/migration and compatibility suites | Package checks PASS; full public release NO-GO, see audit | 2026-10-18 |

Run command for every row: `bundle exec rspec` (and `bundle exec rubocop`). Environment is
the pinned local table above.

### FR-08 delivery evidence (2026-10-17)

```text
$ gem build ruby_llm-browser.gemspec
  Successfully built RubyGem
  Name: ruby_llm-browser
  Version: 0.1.0
  File: ruby_llm-browser-0.1.0.gem

# Clean install into an isolated GEM_HOME, then require from the built gem:
$ gem install --local ./ruby_llm-browser-0.1.0.gem --install-dir "$PKG" --ignore-dependencies
$ GEM_HOME="$PKG" GEM_PATH="$PKG:$(gem env gempath)" ruby -e 'require "ruby_llm/browser"'
framework_loaded=[]        # no railties / active_record / active_job on the core path
core=0.1.0
$ ... ruby -e 'require "ruby_llm/browser/rails"'
rails=RubyLLM::Browser::Rails::OperationJob
```

The packaged gem contains the plain-Ruby core, the opt-in Rails adapter and the install
generator. Public RubyGems publication stays blocked on BR-03 (name/license clearance).

The original install above used `--ignore-dependencies` and borrowed the development
GEM_PATH. It proved loading the artifact, **not** clean dependency resolution. The later
audit's fresh-GEM_HOME installation is the stronger check.

## Release-hardening audit (2026-10-18)

The previous 270-example green suite did not cover several release-critical negative
paths. The initial new audit regressions failed on output ceilings, malformed schemas,
missing result validation, stale starts and early quota release. Those are now fixed.
See the [release audit]({% link RELEASE_AUDIT.md %}) for findings, corrections and remaining gates.

Evidence commands (all provider HTTP is stubbed or disabled):

```bash
bundle exec rake
BUNDLE_GEMFILE=gemfiles/ruby_llm_2_0.gemfile bundle exec rspec
BUNDLE_GEMFILE=gemfiles/rails_8_0.gemfile bundle exec rspec
bundle exec bundle-audit check --update
bundle exec ruby examples/plain_ruby.rb
bundle exec ruby examples/rails_adapter.rb
bundle exec rake build
```

Additional fixtures exercise independent SQLite connections, duplicate start claims,
atomic grant consumption, actual SIGKILL of a fake-backend worker followed by recovery
in a fresh process, post-start persistence errors, real-clock timestamp precision,
Stagehand HTTP retries/serialization, the Rails generator's reversible migration, local
Markdown links, shipped files and executable offline README examples.

| Check | Versions / fixture | Result |
| --- | --- | --- |
| Full default suite | Ruby 3.3.5, RubyLLM 2.1.1, AR/AJ 8.1.4, Stagehand 3.21.0, SQLite 2.10.0 | PASS: 302 examples, 0 failures |
| Minimum RubyLLM | Same, RubyLLM 2.0.0 | PASS: 302 examples, 0 failures |
| Rails 8.0 | Ruby 3.3.5, RubyLLM 2.0.0, AR/AJ 8.0.5.1 | PASS: 302 examples, 0 failures |
| RuboCop | `bundle exec rubocop . bin/verify-package` | PASS: 89 files, 0 offenses |
| Runtime dependency advisories | ruby-advisory-db `fa2295251efb3b0d1a300e5ce8ad700ff1f1b485` | No known vulnerabilities found |
| Live provider egress / TTL / billing / final URL | No live session authorized or run | NOT RUN |
| PostgreSQL concurrency | No PostgreSQL fixture run | NOT RUN |
| Expanded remote CI | Linux Ruby 3.2/3.3/3.4, RubyLLM 2.0.0/2.1.1, Rails 8.1 plus Rails 8.0 row | PASS for `0ec34d4`: seven test jobs plus build/install/advisory job |
| Public release | BR-02, missing live Act protocol, BR-03/04 | NO-GO |

### Stronger package-install evidence

```bash
bundle exec rake build
bundle exec bundle-audit check --update
bundle exec ruby bin/verify-package --rails --audit
```

The verifier installs the actual package and resolves dependencies in a new GEM_HOME
with no borrowed GEM_PATH and no `--ignore-dependencies`. It runs outside the checkout,
checks the activated entrypoint, loads shipped guides/examples, proves core loading has
no eager framework/client, then installs optional Rails dependencies and runs the
installed generator's migration up/down. Output markers:

```text
CORE_PACKAGE_PASS
CLEAN_RUNTIME_ADVISORIES_PASS
RAILS_PACKAGE_PASS
```

The initial fresh install exposed vulnerable default CGI/Resolv/URI/zlib versions that
the project's lockfile scan omitted. After adding patched runtime floors, both the
lockfile scan and a check of the actually activated clean core runtime report no known
advisories. Local resolved security libraries: CGI 0.5.2, Resolv 0.8.1, URI 1.1.2 and
zlib 3.2.4. Native Ruby/system-library security is a separate host responsibility.

Full installer/smoke logs and `activated-versions.json` remain in the temporary evidence
directory printed by the verifier. The verifier prints the artifact SHA-256; a local
`pkg/SHA256SUMS` accompanies the final artifact. Build/install is not publication.

### Submission evidence (2026-10-18)

The hardening is committed and pushed as `0ec34d4b48e0e3ab88bb893c4c731777d2aa24af`.
[CI run 39086570934](https://github.com/yorzi/ruby_llm-browser/actions/runs/39086570934)
completed successfully: all seven test jobs report `302 examples, 0 failures`, and
the package job reports no known dependency advisories plus all three clean-install
success markers. No RubyGems release or paid provider call was performed. Publication
remains NO-GO for the other recorded gates.

## Commit log

Small, meaningful commits land one piece at a time. See `git log` for the authoritative
history; notable slices:

1. Scaffold: gemspec, version, Ruby-only fixture, CI, OSS docs and the baseline record.
2. Core: typed errors, redaction, budgets, results and configuration.
3. Policy: capabilities, URL guard and source/schema/action policy.
4. Lifecycle: operation, approval and in-memory stores.
5. Runtime: backend contract, FakeBackend, Context, Engine and the Inspect/Extract/Act
   tools, with FR-01/03/04/05 evidence (fake backend).
6. Backend: the Stagehand adapter and preflight Doctor (FR-02/03/07 offline evidence).
7. Engine seam: a caller-reserved operation for the Rails job and cleanup bookkeeping
   that tolerates a fenced or cancelled writer.
8. Rails adapter: durable ActiveRecord operation/approval stores, schema and migration.
9. Rails jobs: scoped Active Job, cleanup reaper and the install generator (FR-06).
