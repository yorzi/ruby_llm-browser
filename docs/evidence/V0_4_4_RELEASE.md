# 0.4.4 Release Verification

2026-10-21, Asia/Shanghai. The owner authorized pushing and publishing 0.4.4 with
updated documentation. The release remains offline-only; the original live
deployment milestone is still incomplete.

## Source and Remote Checks

Release commit: `73c072ef215c41e25cfb6cc3bf6b179a4b417705`.
Annotated tag: `v0.4.4`, tag object `0acbe90d2cbebd34ca1a72866f2667a774c54d96`,
resolving to that exact release commit. Earlier tags are unchanged.

[CI run 39521407994](https://github.com/yorzi/ruby_llm-browser/actions/runs/39521407994)
passed all nine jobs. The seven Ruby/RubyLLM/Rails combinations each report 378
examples and zero failures. They cover Ruby 3.2/3.3/3.4, RubyLLM 2.0.0/2.1.1, and
the additional Rails 8.0 combination. Chrome reports eight examples and zero failures.
The build job confirms isolated core/Rails installation and activated runtime advisory
checks. Remote mobile image-denial and blocked Stagehand screenshots were downloaded
and inspected. Four request receipts remain explicitly `qualified: false`.

The pre-tag [Docs run 39521407978](https://github.com/yorzi/ruby_llm-browser/actions/runs/39521407978)
also passed. `V0_4_4_VALIDATION.md` records the local candidate matrix, installed
artifact checks, dependency audit, and local checksums. Local candidate checksums do
not identify the rebuilt public archive.

## Publication and Public Artifact

[Release run 39521581141](https://github.com/yorzi/ruby_llm-browser/actions/runs/39521581141)
passed tagged-package verification and trusted RubyGems publication. It created the
non-draft, non-prerelease
[GitHub Release](https://github.com/yorzi/ruby_llm-browser/releases/tag/v0.4.4)
at 2026-10-21 00:31:19 UTC, or 08:31:19 Asia/Shanghai.

[RubyGems 0.4.4](https://rubygems.org/gems/ruby_llm-browser/versions/0.4.4), its
version-specific API metadata, the actual gem download, GitHub's gem asset, and
`SHA256SUMS` agree on this SHA-256:

`1e985480486a79721d7bef4e1eed47c2a8be584785392cde39a8537232758704`

The two public gem downloads are byte-identical. All 94 payload files match their
bytes at `v0.4.4`. Actual package metadata and RubyGems metadata both point
`documentation_uri` to `https://rubyllm-browser.wangyaodi.com`. No development
fixtures, test bundles, or local evidence are packaged. The first version-specific
API lookup reused a cached 404 from the pre-release existence check; a fresh lookup
and the versions index confirmed publication. No second publication was attempted.

The actual public gem was then installed in a new isolated GEM_HOME with
`bin/verify-package --rails --audit`, without ignoring dependencies. It passed
`CORE_PACKAGE_PASS`, `CLEAN_RUNTIME_ADVISORIES_PASS`, and `RAILS_PACKAGE_PASS`,
including the generator migration and separate-worker result example. Install
evidence remains at
`/var/folders/lg/2wcb539s3x79yz10zq8ltv1m0000gn/T/browser-package-20261021-33688-z7ddk0/`.

## Hosted Documentation

The post-release [Docs run 39521827439](https://github.com/yorzi/ruby_llm-browser/actions/runs/39521827439)
completed build and deployment. Its downloaded Pages artifact passes 4,180 generated
links with zero broken links and no published evidence directory. The local tagged
build passes 7,990 links with zero broken links. Counts differ with the RDoc toolchain;
each result describes its own checked output.

Direct HTTPS verification passed 21 content assertions across 12 stable and `/next/`
endpoints. Checks cover the 0.4.4 install requirement, What's New, upgrading, local
deployment feasibility, release history, the old 0.3 guide URL, the latest-guide
redirect, API index, and `llms.txt`. A fresh browser review of
[Getting Started](https://rubyllm-browser.wangyaodi.com/getting-started/) confirms
stable 0.4.4 and the Gemfile requirement `~> 0.4.4`.

The README stays concise. Detailed usage stays in the site and distributed Markdown.
The stable site builds from the tag; `/next/` follows `main`. What's New in 0.3 stays
under Release History with its URL preserved. The roadmap explicitly keeps live
qualification open rather than treating offline canaries as isolation evidence.

## Retained Evidence and Cleanup

Ignored `tmp/release-0.4.4/` contains CI/release logs, public downloads, metadata,
checksum/source comparison reports, isolated install output, remote screenshots and
receipts, the deployed site artifact, HTTPS assertions, and `stable-docs.png`.

The browser review tab is closed. Test Chrome/driver process inspection reports no
remaining processes. Test hosts and install workers have exited; no task-owned
preview, Stagehand server, watcher, or other long-running service remains.
No real provider session, model request, live egress/expiry/cleanup qualification,
or billable browser operation was performed.
