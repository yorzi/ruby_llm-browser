# 0.3.0 candidate validation

Date: 2026-10-19 (Asia/Shanghai). This is local candidate evidence, not a release,
remote CI result, provider qualification, or production guarantee.

## Candidate identity

- Source and packaged documentation: `51a812a5650e0ea14a543c7fa73edcb547847b39`.
- Feature commits: `81f0002` (delivery callback) and `a48478f` (host example and recovery).
- Artifact: `pkg/ruby_llm-browser-0.3.0.gem`.
- SHA-256: `ee76c7acda872c56bc3a99126ee90b2b240dd381c966823ab3157ca6b8a8ba87`.
- `released: false`; stable version remains `0.2.0`. No 0.3.0 tag is created.
- This evidence file is excluded from the gem and generated site. Adding it does not
  change the validated artifact.

## Implemented scope

`Rails.result_delivery` is opt-in and synchronous. It receives the sanitized `Result`
and an immutable operation snapshot after execution and cleanup. The host owns
persistence, authorization, retention, idempotency and recovery. No gem-managed tables
or runtime dependencies are added.

Callback failures raise `Rails::ResultDeliveryError` with retained in-process result
and operation objects, with no chained host exception. They do not change session
state or error code. Duplicate browser jobs neither start again nor redeliver. Cancelled
and fenced workers cannot deliver a result when those conditions are detected after
execution. Host revocation can race with the final check, so host persistence and
read authorization remain necessary.

The SQLite example serializes an Active Job, executes it in a separate worker, waits
for exit, and retrieves the stored extraction. It rejects actor/run mismatches and
conflicting deliveries, while accepting identical duplicate writes. The file queue
is a single-job demonstration, not a production queue.

`Result` now defensively copies and freezes operation ID and error strings as well as
its other retained fields. A failing public-contract test reproduced constructor-input
mutation changing the original result before the fix. The upgrade guide records the
new `FrozenError` behavior for callers that mutate these attributes.

## Verification

Host: Ruby 3.3.5, arm64 macOS. All database suites run sequentially.

Command: `CHROMEDRIVER=/Users/andy/.cache/selenium/chromedriver/mac-arm64/155.0.8059.79/chromedriver bin/check --browser --package`.

| Check | Result |
| --- | --- |
| RubyLLM 2.1.1 / Rails 8.1.4 | 353 examples, 0 failures |
| RubyLLM 2.0.0 / Rails 8.1.4 | 353 examples, 0 failures |
| RubyLLM 2.0.0 / Rails 8.0.5.1 | 353 examples, 0 failures |
| RuboCop | 109 files, no offenses |
| Offline plain Ruby, Rails adapter, and durable result examples | PASS |
| Chrome desktop/mobile fixture | 4 examples, 0 failures |
| Candidate metadata and package exclusions | PASS, 92 shipped files |
| Isolated core installation and examples | `CORE_PACKAGE_PASS` |
| Activated core runtime advisory audit | `CLEAN_RUNTIME_ADVISORIES_PASS` |
| Isolated Rails installation, examples and generator | `RAILS_PACKAGE_PASS` |
| Documentation build | PASS: stable 0.2.0 at `/`, candidate at `/next/` |
| Generated site links and evidence exclusion | 7,476 local links, 0 broken |
| Documentation lint | 19 guides, 0 errors; 10 reviewed warnings |

The documentation warnings concern legacy Markdown pointer links, historical evidence
links, and the intentional unreleased version ahead of the latest tag. The impact
check's example helper names are demonstration code, not loaded gem APIs; the setter
`result_delivery=` is documented through assignment examples and configuration text.

Chrome artifacts: `tmp/browser/20261019T122504-12372/`. Reviewed extraction success,
blocked Stagehand diagnostics, and mobile keyboard recovery screenshots. Existing
workbench assertions check dispatch, cleanup and viewport width; these screenshots
do not validate asynchronous Rails result storage. Separate process tests do that.

The result-delivery tests cover success, truncation, redaction, schema rejection,
provider rejection, unknown starts, pending cleanup, preflight denial, cancellation
before/during execution, fencing, duplicate jobs, and delivery failure preserving state
and quota. Process tests block unmocked HTTP in both parent and child workers. They
exercise failures before persistence and after persistence, idempotent recovery,
conflicting payload/scope rejection, and reads after worker exit.

A worker killed in the callback before storage leaves a closed operation and no result.
The test proves that queue redelivery does not recreate that result or repeat browser
work. The callback cannot guarantee delivery across that crash gap. An error object is
not durable storage. Host recovery must retain the result before its process exits.

The upgrade test loads the frozen 0.2.0 migration, seeds operation, approval and actor
rows, and verifies unchanged rows, operation indexes, and existing migration content
after fixture schema boot and skipped duplicate generation. Production upgrades do not
rerun the installer. SQLite is tested; PostgreSQL upgrade/concurrency is not qualified.

`bundle exec bundle-audit check --update` passes against advisory database commit
`fa2295251efb3b0d1a300e5ce8ad700ff1f1b485` (1,266 advisories). The clean core runtime
activates RubyLLM 2.1.1, Stagehand 3.21.0, Schematist 1.1.0, JSONSchemer 2.5.0, CGI
0.5.2, Resolv 0.8.1, URI 1.1.2 and zlib 3.2.4. The development bundle uses sqlite3
2.10.0. The audit is a known-advisory check, not a guarantee of no vulnerabilities.

Local logs are in `/tmp/browser-v0-3-candidate.log`, `/tmp/browser-v0-3-docs.log`, and
`/tmp/browser-v0-3-audit.log`. Isolated install logs and activated core versions are in
`/var/folders/lg/2wcb539s3x79yz10zq8ltv1m0000gn/T/browser-package-20261019-12485-nc0lln/`.

## Remaining boundaries and next steps

- Remote CI has not run for this candidate. Ruby 3.2 and 3.4 are configured CI targets,
  not local results. Push and verify every matrix, Chrome, package and documentation job
  against the exact candidate before preparing release metadata.
- No tag, GitHub Release, RubyGems publication or hosted documentation update is part of
  this development validation. Stable documentation and the published gem remain 0.2.0.
- Stagehand and live Act remain unsupported. No provider calls, paid sessions, live
  egress, TTL, cleanup or billing qualification is performed.
- After the 0.3.0 release gate, the roadmap's next milestone is an offline feasibility
  check for one named live read-only deployment. Live qualification needs separate
  deployment/data/spending authorization; do not infer support from these fixtures.
- The full candidate command exits successfully. All task-owned Chrome sessions,
  loopback fixture servers, drivers, worker subprocesses and install processes exit.
  No preview server or watcher is left running.
