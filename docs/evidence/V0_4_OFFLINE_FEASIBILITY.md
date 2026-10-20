# 0.4.0 Offline Feasibility Checkpoint

Date: 2026-10-20. This is a development checkpoint, not release-candidate or live
deployment qualification. The owner selected a pinned local Stagehand deployment
with a host-controlled browser network and authorized offline work only.

## Changes

- Commit `02e1caa` fixes local executable identity. A version label alone is not a
  pin because SDK 3.21.0 uses its existing server cache before the version setting.
  An absolute executable path and host-approved SHA-256 are now required. The
  adapter rechecks current bytes and the real SDK process environment. A valid pin
  never enables live operations.
- Local SDK HTTP contracts verify explicit local CDP attachment serialization,
  Browserbase credential defaults, managed endpoint replacement, nullable navigation
  results, end acknowledgements without terminal state, and no lost-start retries.
  The SDK server manager is intercepted; HTTP uses WebMock and synthetic values.
- Opted-in routes on the maintained workbench calibrate network canaries. Same-origin
  and cross-origin controls receive fetch, image, script, frame, popup, Worker fetch,
  and WebSocket upgrade requests. Image blocking removes only that canary. A redirect
  test reads the actual destination from Chrome. WebSocket receipts require Upgrade
  and Connection headers; the fixture returns 426 without opening a tunnel.
- `bin/check-local-stagehand` pins SDK 3.21.0 in a separate development bundle. CI's
  browser job now includes the canaries and retains screenshots plus JSON receipts.

## Verified Locally

All checks below used Ruby 3.3.5 on macOS. Database suites ran sequentially.

| Check | Result |
| --- | --- |
| Failing executable-identity regressions before implementation | 12 failures, including incorrect version-only and path-only pins |
| Failing workbench probe contracts before implementation | 6 failures |
| Failing plain-GET WebSocket receipt regression before the header check | 1 failure |
| `bin/check --browser`: RubyLLM 2.1.1 / ActiveRecord 8.1.4 | 378 examples, 0 failures |
| RubyLLM 2.0.0 / ActiveRecord 8.1.4 | 378 examples, 0 failures |
| RubyLLM 2.0.0 / ActiveRecord 8.0.5.1 | 378 examples, 0 failures |
| RuboCop | 115 files, no offenses |
| Plain Ruby, Rails adapter, Rails result examples | Passed, including separate-worker result retrieval and scoped reads |
| Chrome 155.0.8059.85: workbench and network calibration | 8 examples, 0 failures; 8 screenshots and 4 receipts |
| Final `bin/check-local-stagehand` with installed ChromeDriver | 22 examples, 0 failures; 4 screenshots and 4 receipts |
| Documentation rules | 20 guides, 0 errors; 9 existing legacy/evidence-link warnings |
| `docs/bin/build.sh` | Stable v0.3.0 and current `/next/` generated successfully |
| `python3 scripts/check_docs_site.py` | 7,782 links, 0 broken; evidence excluded from rendered site |

Desktop, mobile keyboard/overflow, blocked Stagehand diagnostics, and image-denial
screenshots were inspected. The final canary receipts report one request of each
expected kind. The image-denial receipt has six kinds with no image hit. Every receipt
declares `qualified: false`.

Ignored artifacts:

- `tmp/v0-4-final-check.log`
- `tmp/browser/20261020T054406-44941/`
- `tmp/v0-4-local-stagehand-final.log`
- `tmp/local-stagehand/20261020T054504-45517/`
- `tmp/v0-4-docs-build.log`

The tests quit their browser/driver sessions. Puma exits with each test process.
No manual preview, watcher, Stagehand server, or other task-owned service remains.

## Not Established

No Stagehand server artifact, isolated browser image, gateway, or independent process
supervisor has been qualified. The local Docker client is installed but its daemon
socket is absent. No Docker daemon was started for this checkpoint.

These tests do not establish enforced egress, connection-time DNS/IP restrictions,
DNS rebinding protection, IPv6/UDP/QUIC denial, HTTPS CONNECT, successful WS/WSS
tunnels, service-worker isolation, expiry after worker death, lost-start recovery,
confirmed teardown, billing limits, or provider extraction correctness. No real
Stagehand or model/provider request ran. The core adapter and live Act remain blocked.

Remote CI, hosted `/next/` deployment, a fresh candidate installation, and publication
have not been run for these local commits. Version remains 0.3.0 with Unreleased
changes; no 0.4.0 tag or release was created.

## Next Development Step

Provide a Linux browser network namespace or equivalent enforced runtime. Pin the
reviewed server executable and browser artifacts, then implement and test the egress
gateway and independently owned lifecycle supervisor against controlled destinations.
Use the calibrated canaries as positive controls before testing denials. Integrate
the local adapter only after those host contracts are demonstrated. Continue offline
until deployment, data, and spending receive separate authorization for live tests.
