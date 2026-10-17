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
| Rails / Active Job | optional dev fixtures |
| Command | `bundle exec rspec` and `bundle exec rubocop` |

## Progress slices (S0 → S4)

| Slice | Deliverable | State |
| --- | --- | --- |
| S0 | Bootstrap: gemspec, version, Ruby-only fixture, CI, OSS docs, baseline record | DONE |
| S1 | Read-only `Inspect`/`Extract` core with fake backend, policy, bounded results | DONE |
| S2 | Stagehand adapter, durable operation store, quotas, TTL/reaper, reconciliation | PLANNED |
| S3 | Opt-in `Act` with one-use approvals, Rails 8 jobs, cancellation, negative tests | PARTIAL (Gem-core Act + approvals done; Rails 8 jobs pending) |
| S4 | Full matrix, clean install, security/compat/license docs, human-approved release | PLANNED |

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
| FR-05 approved Act | `spec/ruby_llm/browser/act_spec.rb`, `spec/ruby_llm/browser/engine_spec.rb` | same | PASS (fake); bare `Chat#approve` dispatches nothing | 2026-10-17 |
| FR-06 Rails jobs | `spec/rails/operation_job_spec.rb` | same | NOT RUN | — |
| FR-07 failure/budget/audit | `spec/ruby_llm/browser/engine_spec.rb` (budget, redaction) | Stagehand env-override / SDK retry spec | PARTIAL (budget PASS; Stagehand adapter NOT RUN) | 2026-10-17 |
| FR-08 full delivery | `gem build` + CI | same | NOT RUN | — |

Run command for every row: `bundle exec rspec` (and `bundle exec rubocop`). Environment is
the pinned local table above.

## Commit log

Small, meaningful commits land one piece at a time. See `git log` for the authoritative
history; notable slices:

1. Scaffold: gemspec, version, Ruby-only fixture, CI, OSS docs and the baseline record.
2. Core: typed errors, redaction, budgets, results and configuration.
3. Policy: capabilities, URL guard and source/schema/action policy.
4. Lifecycle: operation, approval and in-memory stores.
5. Runtime: backend contract, FakeBackend, Context, Engine and the Inspect/Extract/Act
   tools, with FR-01/03/04/05 evidence (fake backend).
