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
| S1 | Read-only `Inspect`/`Extract` core with fake backend, policy, bounded results | IN PROGRESS |
| S2 | Stagehand adapter, durable operation store, quotas, TTL/reaper, reconciliation | PLANNED |
| S3 | Opt-in `Act` with one-use approvals, Rails 8 jobs, cancellation, negative tests | PLANNED |
| S4 | Full matrix, clean install, security/compat/license docs, human-approved release | PLANNED |

## Functional-requirement evidence

All rows start as `NOT RUN` and are filled in as tests land. Columns: test file(s), run
command, result, date.

| FR | Positive | Denial / fault | Result | Date |
| --- | --- | --- | --- | --- |
| FR-01 Tool + configuration | `spec/ruby_llm/browser/inspect_spec.rb` | `spec/.../inspect_spec.rb` | NOT RUN | — |
| FR-02 session/operation | `spec/ruby_llm/browser/engine_spec.rb` | same | NOT RUN | — |
| FR-03 read-only inspect | `spec/security/url_guard_spec.rb` | same | NOT RUN | — |
| FR-04 structured extract | `spec/.../extract_spec.rb` | same | NOT RUN | — |
| FR-05 approved Act | `spec/.../act_spec.rb` | same | NOT RUN | — |
| FR-06 Rails jobs | `spec/rails/operation_job_spec.rb` | same | NOT RUN | — |
| FR-07 failure/budget/audit | `spec/.../stagehand_backend_spec.rb` | same | NOT RUN | — |
| FR-08 full delivery | `gem build` + CI | same | NOT RUN | — |

## Commit log

Small, meaningful commits land one piece at a time. See `git log` for the authoritative
history; notable slices:

1. Scaffold: gemspec, version, Ruby-only fixture, CI, OSS docs and the baseline record.
