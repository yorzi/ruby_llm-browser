---
layout: default
title: Local Stagehand feasibility
nav_order: 5
description: Run offline checks for a pinned local Stagehand deployment and identify the remaining isolation requirements.
---

# {{ page.title }}

{{ page.description }}

After reading this guide, you will know:

- How to run the local SDK contracts and browser canaries without a provider.
- Which parts of a local deployment need separate host controls.
- What still blocks the proposed 0.4.0 release.

## Run the Offline Fixtures

```sh
BUNDLE_GEMFILE=gemfiles/local_stagehand.gemfile bundle install
bin/check-local-stagehand
```

The source-checkout runner pins the Ruby SDK to `stagehand 3.21.0`. It runs the
local HTTP contracts, executable identity regressions, and Chrome network canaries.
It does not start Stagehand, download a server binary, or call a model. HTTP contracts
use empty or synthetic credentials. Use `CHROME_BIN` and `CHROMEDRIVER` to select installed browser binaries.
Installing dependencies may access the package registry. Once dependencies and a
matching driver are installed, fixture execution needs only loopback access.

The runner prints an ignored `tmp/local-stagehand/` directory containing screenshots
and per-case JSON receipts. Each receipt declares `qualified: false`, the Chrome
version, expected received request kinds, and actual server counters. A successful
run establishes fixture calibration and SDK serialization, not a supported deployment.
The fixture has no user-supplied destination URL and both origins point to loopback.

You can also run `bin/check-browser --network` to combine the canaries with the
existing workbench workflows. `bin/check --browser` includes them. The network routes
are enabled only for the test instance of `dev/workbench.rb`. Normal `bin/workbench`
does not expose them. All browser dependencies remain outside runtime dependencies.

## Understand the Controls

The same-origin control sends seven request types: fetch, image, script, iframe,
popup, Worker fetch, and a WebSocket upgrade. The cross-origin control changes the
destination from `127.0.0.1` to `localhost` on the same loopback server. An unrestricted
Chrome must reach every canary. This detects tests that appear to deny a request only
because the browser never sent it.

A third control blocks the image through the current Chrome target's CDP network
settings. The image fails while the other six canaries still arrive. The mobile test
uses keyboard activation and checks overflow. This is a partial-denial calibration;
CDP URL blocking is not the deployment's security boundary. A redirect scenario
reads the resulting URL from Chrome and checks that the destination server received
the request.

The WebSocket endpoint records the HTTP upgrade request, then returns `426`. It does
not open a tunnel. These tests do not qualify a successful WebSocket connection,
WSS, HTTPS CONNECT, DNS changes, service workers, QUIC, IPv6 routing, or a production
firewall. A later isolation run must test positive connectivity and forbidden
destinations through the actual browser namespace, including every child target.

## Account for the Pinned SDK

The local HTTP suite uses the real SDK serializer with stubbed HTTP. It intercepts
the SDK's server manager before process creation. The assertions establish these
properties of SDK 3.21.0:

| SDK behavior | Deployment consequence |
| --- | --- |
| `browser: { type: :local, cdp_url: ... }` serializes an attached browser without Browserbase credentials | You can investigate a separately supervised Chrome instead of letting Stagehand launch it |
| Omitting the local browser type requires Browserbase credentials | A future adapter must explicitly select the local browser |
| Local mode replaces a supplied `base_url` with its managed server endpoint | Passing a local URL does not attach to an externally supervised Stagehand server |
| Navigation accepts `result: nil` | The host needs an independent, same-session final-URL check |
| Ending a session returns `success` without terminal state | The host must confirm browser termination separately |
| A lost start response raises after one request when retries are disabled | Recovery must retain quota until the supervisor resolves the owned browser |

Read the pinned [SDK source](https://github.com/browserbase/stagehand-ruby/tree/v3.21.0/lib/stagehand)
when changing these contracts. A stubbed response does not prove that a particular
server binary implements the serialized options. Server compatibility still needs
an offline, controlled deployment run before any model call.

The gem's `StagehandBackend` remains unsupported. These SDK experiments do not add
local browser attachment or Browserbase-free construction to its public API. Its
local executable diagnostic requires an absolute `STAGEHAND_SEA_BINARY` and the
host-approved `server_binary_sha256:`. See
[API and configuration]({% link _reference/api-and-configuration.md %}) for the pinning
contract and filesystem trust boundary.

## Build the Deployment Boundary Next

The selected direction is local Stagehand with a host-controlled browser network.
Use a separately owned Linux browser namespace or equivalent enforced boundary. Keep
the Stagehand model connection outside that namespace. The browser must have no
direct route around the host's egress gateway, including loopback, host services,
IPv6, UDP, and new browser targets. A Chrome proxy flag alone does not establish this.

The gateway must enforce approved hosts and ports at connection time, reject private
and mixed public/private DNS answers, and connect to the validated numeric address.
Test denied redirects and every canary against the actual boundary. Fix the server
binary hash, browser artifact, network configuration, and gateway version in the
qualification evidence. No such deployment is qualified yet.

An independent supervisor must own the browser before the Stagehand start request,
bind it to the durable operation, enforce expiry after worker death, and confirm
process and network teardown. A lost start response must remain reconcilable without
a second start. A successful end response or a closed CDP connection alone cannot
release quota. Keep unresolved operations visible for host review.

Complete these offline deployment checks before requesting a separate live run.
Keep Stagehand and live Act disabled until the
[0.4.0 acceptance criteria]({% link _reference/roadmap.md %}) pass.

## Next Steps

- Read [Qualifying a live backend]({% link _advanced/live-backend-qualification.md %}) for the full acceptance boundary.
- Follow [Development and Testing]({% link _advanced/development-and-testing.md %}) for the regression and package checks.
