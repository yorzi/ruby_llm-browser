# 0.4.4 Local Release Validation

2026-10-21, Asia/Shanghai. The owner authorized pushing and publishing 0.4.4 with
updated documentation. This release ships the existing offline groundwork from
`02e1caa` and `60b35ee`, plus the documentation metadata fix from `6526640`.
It does not complete the original live-deployment milestone.

## Source and Documentation

The version, README, dated changelog, What's New, upgrade guide, release history,
navigation, and roadmap now describe 0.4.4. The 0.3 What's New guide moves to Release
History with its URL preserved. The upgrade guide documents the new checksum
requirement without a runtime dependency or database migration. Stagehand and live
Act remain unsupported. The live deployment gate stays open before pilot work.

The package-content regression initially failed because the historical guide moved.
It now requires both the moved guide and the new release/local-deployment guides.
The focused package/documentation suite passes four examples.

## Completed Checks

All local Ruby checks use Ruby 3.3.5 on arm64 macOS. Database suites run sequentially.

| Check | Result |
| --- | --- |
| `bin/check --browser --package`, RubyLLM 2.1.1 / Rails 8.1.4 | 378 examples, 0 failures |
| RubyLLM 2.0.0 / Rails 8.1.4 | 378 examples, 0 failures |
| RubyLLM 2.0.0 / Rails 8.0.5.1 | 378 examples, 0 failures |
| RuboCop | 115 files, no offenses |
| Plain Ruby, Rails adapter, durable Rails result examples | Passed |
| Offline Chrome workflows and network controls | 8 examples, 0 failures |
| Pinned Stagehand 3.21.0 fixture runner | 22 examples, 0 failures |
| Candidate and released metadata checks | Passed; 94 packaged files |
| Clean core and optional Rails installation | Passed, including generator migration and separate-worker result retrieval |
| Refreshed dependency audit and activated core-runtime audit | No known vulnerabilities |
| Documentation build before tagging | Stable v0.3.0 plus current `/next/`; 7,851 links, 0 broken; evidence excluded |

The advisory database contains 1,266 advisories at commit
`5fd86bbd406995ea4ed2df84651b209e28072031`. Desktop and mobile image-denial
screenshots were inspected. Canary receipts remain explicitly `qualified: false`.
The source documentation rules pass 21 guides with no errors. Nine warnings concern
existing legacy pointers or historical evidence. Before the new tag exists, the
version/tag mismatch is an additional expected warning.

The candidate package tested in isolation has SHA-256:

`7e06b794a6328c152fb3245b1dff02dad6839105d04b5645fbc7fa33d1121b0e`

Its snapshot is retained at `tmp/release-0.4.4/candidate.gem`. The isolated installation
evidence directory is
`/var/folders/lg/2wcb539s3x79yz10zq8ltv1m0000gn/T/browser-package-20261021-28107-uiajre/`.

After setting released metadata and the dated changelog, the local final build has
SHA-256 `1fa7079933e07e64aacf93a06cc9eee6b22b9589e85333b8cc43dcb5f004d37a`.
The release workflow rebuilds the archive. Neither local checksum is a claim about
the later public artifact. Publication verification must compare actual GitHub and
RubyGems downloads and install that public artifact separately.

Ignored logs and browser artifacts:

- `tmp/release-0.4.4/local-check.log`
- `tmp/release-0.4.4/local-stagehand.log`
- `tmp/release-0.4.4/docs-build.log`
- `tmp/browser/20261021T002513-27887/`
- `tmp/local-stagehand/20261021T002602-29545/`

## Boundaries

No real Stagehand server, provider session, model request, or billable browser
operation ran. These checks do not qualify network isolation, connection-time DNS/IP
enforcement, server compatibility, expiry, teardown, lost-start recovery, or billing.
The release is offline-only. Remote CI, public package checks, hosted documentation,
and final process cleanup are recorded separately after completion.
