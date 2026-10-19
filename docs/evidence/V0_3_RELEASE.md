# 0.3.0 release verification

2026-10-19 (Asia/Shanghai). Andy authorized publishing 0.3.0 and updating its
related documentation. The release remains offline-only.

## Source and candidate

Release source: `6de14f3b3f62ea6dba5d5d278c05be2b3c349c6b`.
Annotated tag: `v0.3.0`, pointing at that exact commit. Earlier tags are unchanged.

Candidate `07d78a2d534128ea2fd2c199b392a275eb3722f3` passed all nine jobs in
[CI run 39252937900](https://github.com/yorzi/ruby_llm-browser/actions/runs/39252937900)
and completed [Docs run 39252937814](https://github.com/yorzi/ruby_llm-browser/actions/runs/39252937814).
Its downloaded documentation artifact passed 3,756 local links, zero broken.
`V0_3_VALIDATION.md` remains the historical local candidate record; its checksum
identifies that candidate, not the final public release.

README, released metadata, dated changelog, What's New, upgrade instructions, release
history and roadmap status were updated before tagging. The 0.2 What's New guide
moved to Release History with its URL preserved. The 0.3 upgrade guide explains
opt-in delivery, immutable result strings, fencing, and the persistence crash gap.

## Release checks

[Final CI run 39253243272](https://github.com/yorzi/ruby_llm-browser/actions/runs/39253243272)
passed all nine jobs at the release commit. All seven Ruby/RubyLLM/Rails jobs report
353 examples, zero failures. They cover Ruby 3.2/3.3/3.4, RubyLLM 2.0.0/2.1.1 and the
additional Rails 8.0 combination. Chrome reports four examples, zero failures.
The build job reports `CORE_PACKAGE_PASS`, `CLEAN_RUNTIME_ADVISORIES_PASS` and
`RAILS_PACKAGE_PASS`. Remote mobile recovery and blocked Stagehand screenshots were
downloaded and inspected under `/tmp/browser-v0-3-remote-screenshots/`.

[Release run 39253586159](https://github.com/yorzi/ruby_llm-browser/actions/runs/39253586159)
passed tagged-package verification and RubyGems trusted publication, and created the
public, non-draft, non-prerelease
[GitHub Release](https://github.com/yorzi/ruby_llm-browser/releases/tag/v0.3.0).
Publication completed at 2026-10-19 12:40:47 UTC (20:40:47 Asia/Shanghai).

RubyGems lists [ruby_llm-browser 0.3.0](https://rubygems.org/gems/ruby_llm-browser/versions/0.3.0).
The actual RubyGems download, version-specific API metadata, GitHub Release download
and `SHA256SUMS` agree on this SHA-256:

`47edb51643ed1a5bf429696d64e88222183202b70565408c559e2c552330dc57`

Both public gem downloads are byte-identical. Every one of the 92 packaged files
matches its bytes at `v0.3.0`. Package metadata confirms the correct name, version and
Ruby requirement. The artifact contains the host result example and both release
guides, without development fixtures or local evidence. These checks do not assert
reproducible gem archives across builds or platforms.

The pre-publication local release archive had SHA-256
`e1bde373ca6fcd1901dfa0f8c8215983177e95c8d5c510cc7659abc15c079d8e`.
`bin/check --browser --package` passed against that archive: three local combinations
with 353 examples each, RuboCop on 109 files, four Chrome scenarios, all three examples,
and isolated core/Rails installation and advisory checks.

The actual public gem was then installed into a new isolated GEM_HOME using
`bin/verify-package --rails --audit`, without ignoring dependencies. It passed
`CORE_PACKAGE_PASS`, `CLEAN_RUNTIME_ADVISORIES_PASS` and `RAILS_PACKAGE_PASS`, including
the separate-worker durable result example and the generated migration up/down.
Install evidence is retained at
`/var/folders/lg/2wcb539s3x79yz10zq8ltv1m0000gn/T/browser-package-20261019-19123-pfajwx/`.
Public assets, API metadata, final CI logs, install output and the stable-site screenshot
are retained under ignored `tmp/release-0.3.0/`.

## Documentation deployment

[Post-release Docs run 39253943616](https://github.com/yorzi/ruby_llm-browser/actions/runs/39253943616)
completed build and deployment successfully. Its actual downloaded site artifact passes
3,900 local links, zero broken, and excludes local evidence. The local tagged build
passes 7,712 links, zero broken. Different RDoc toolchains produce different link counts;
each count describes its own checked output. Docs lint reports 19 guides, zero errors,
and eight reviewed legacy-pointer/historical-evidence warnings.

Direct HTTPS checks and an IAB visual review of the
[stable documentation](https://rubyllm-browser.wangyaodi.com/getting-started/) confirm
`0.3.0 (stable)` and the Gemfile requirement `~> 0.3.0`. `llms.txt` names the same stable
version. The sidebar contains Rails Result Delivery and What's New in 0.3, with 0.2
retained under Release History. The stable build comes from the release tag; `/next/`
continues to follow `main`.

Screenshot: `tmp/release-0.3.0/stable-docs.png`.

## Scope and cleanup

Result delivery remains opt-in and host-owned. A worker crash before host persistence
can lose a result. Duplicate jobs do not replay browser work or redeliver that result.
These limits remain visible in the published guide and release upgrade instructions.
Stagehand and live Act remain unsupported; no provider sessions or live egress, TTL,
cleanup or billing qualification was performed.

All local checks and install processes have exited. The IAB review tab is closed;
no preview server, browser driver, watcher or worker is left running. Candidate and
release evidence stay excluded from both the gem and the public documentation site.
