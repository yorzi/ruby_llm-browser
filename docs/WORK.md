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
| S2 | Stagehand adapter, durable operation store, quotas, TTL/reaper, reconciliation | DONE (offline: adapter + AR durable store/reaper; live remote NOT RUN) |
| S3 | Opt-in `Act` with one-use approvals, Rails 8 jobs, cancellation, negative tests | DONE (offline: Gem-core Act + approvals + Rails Active Job/reaper; live NOT RUN) |
| S4 | Full matrix, clean install, security/compat/license docs, human-approved release | PARTIAL (Gem builds; clean-install + release checks pending) |

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
| FR-06 Rails jobs | `spec/rails/operation_job_spec.rb`, `spec/rails/reaper_spec.rb`, `spec/rails/active_record_operation_store_spec.rb`, `spec/rails/active_record_approval_store_spec.rb` | same (wrong actor, fenced-out worker, cancel-mid-session, cleanup_pending visible) | PASS (fake backend + in-memory SQLite) | 2026-10-17 |
| FR-07 failure/budget/audit | `spec/ruby_llm/browser/engine_spec.rb` (budget, redaction), `spec/ruby_llm/browser/stagehand_backend_spec.rb` | `spec/ruby_llm/browser/stagehand_backend_spec.rb` (env override, SDK retry off, `cdp_url`), `spec/ruby_llm/browser/doctor_spec.rb` | PASS (offline); live Stagehand NOT RUN | 2026-10-17 |
| FR-08 full delivery | `gem build` + CI | same | NOT RUN (build next) | — |

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
6. Backend: the Stagehand adapter and preflight Doctor (FR-02/03/07 offline evidence).
7. Engine seam: a caller-reserved operation for the Rails job and cleanup bookkeeping
   that tolerates a fenced or cancelled writer.
8. Rails adapter: durable ActiveRecord operation/approval stores, schema and migration.
9. Rails jobs: scoped Active Job, cleanup reaper and the install generator (FR-06).
