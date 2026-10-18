---
layout: default
title: Development and Testing
nav_order: 3
description: Verify changes with offline contracts, installed packages, and a local browser workbench.
---

# {{ page.title }}

{{ page.description }}

After reading this guide, you will know:

- How to run the local verification loop.
- How to review browser behavior and retain fixture screenshots.
- What offline, browser, and installed-package checks establish.

## Run the Offline Checks

```sh
bin/setup
bin/check
```

Start a behavior change with a focused failing spec. Implement the smallest public
contract, update its guide, then run `bin/check`. The command runs specs and RuboCop,
the RubyLLM 2.0 and Rails 8.0 alternate bundles, and the plain-Ruby and Rails examples.
Install each alternate bundle first if needed. Database suites run sequentially.
RuboCop uses the writable `tmp/rubocop` cache. Default tests block unmocked HTTP.

Commit each completed change with its docs and checks. Keep the next work item in the
[roadmap]({% link _reference/roadmap.md %}); do not create a second task ledger.

## Review the Offline Workbench

```sh
BUNDLE_GEMFILE=gemfiles/browser.gemfile bundle install
bin/workbench
# Open http://127.0.0.1:4024, then Ctrl-C to stop.
```

The single fixture in `dev/workbench.rb` runs the real Ruby tools with FakeBackend,
a deterministic resolver, and an in-memory operation store. Inspect and Extract show
their returned hashes and fake start/cleanup counts. Enter an unapproved host to
exercise a denial, or run Doctor without starting a provider session.

The host serves local HTML and CSS, escapes returned content, requires a form token,
and accepts loopback Host values only. It is a development fixture, not a production
controller or a new public gem API. It does not load the requested page or use provider
credentials. The fixture and browser libraries are excluded from the gem.

## Run Browser Tests

```sh
bin/check-browser
# Or include browser tests after the offline checks:
bin/check --browser
```

Use installed Chrome. `CHROME_BIN` can select its binary; `CHROMEDRIVER` can select an
installed matching driver to avoid Selenium Manager's driver resolution. Screenshots
go into the printed, ignored `tmp/browser/` directory. The runner fails if tests fail
or no screenshot is produced. CI retains fixture screenshots for seven days.

Browser scenarios cover inspect/extract, denial before dispatch, keyboard recovery at
a 390px device viewport, and Doctor output. Capture screenshots before closing the
active session, including on assertion failures. Inspect failure artifacts before
retrying. Screenshots support visual review; assertions establish the expected behavior.

The Puma host and Selenium port probe bind loopback. Browser test HTTP clients allow
loopback only; this is not a Chrome network firewall. No live provider request is part
of this suite. Tests close their driver sessions, and Puma ends with the test process.
Stop manual previews and verify no task-owned service remains after your review.

## Verify a Candidate Package

```sh
bin/check --browser --package
docs/bin/build.sh
```

The package option builds the gem and runs `bin/verify-package --rails --audit`. It
installs into an empty GEM_HOME outside the checkout, resolves dependencies from the
registry, runs shipped examples, tests the generated migration, and audits the activated
runtime. Refresh the advisory database first with `bundle exec bundle-audit check --update`.
Package verification needs registry access; offline test success cannot replace it.

Record the exact artifact hash, dependency versions, checks, and not-run boundaries in
the candidate validation note. Local browser tests prove fixture application wiring.
They do not establish real provider egress, session TTL, cleanup, billing, external
adoption, remote CI success, or publication. Follow the
[release checklist]({% link RELEASING.md %}) before releasing.
