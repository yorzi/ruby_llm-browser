# 0.2.0 release verification

2026-10-19 (Asia/Shanghai). Andy explicitly authorized pushing, tagging, publishing,
remote CI verification, and documentation updates. This release retains the offline-only
scope. The instruction does not authorize live browser/model provider calls.

## Candidate verification

Candidate `1f71a0d83f239b9769d1829585b4640cd8a3dd46` was pushed to `main`.
[CI run 39178199043](https://github.com/yorzi/ruby_llm-browser/actions/runs/39178199043)
passed all nine jobs: seven Ruby/RubyLLM/Rails combinations, the Chrome workflows,
and isolated package verification. The matrix includes Ruby 3.2, 3.3, and 3.4,
RubyLLM 2.0.0 and 2.1.1, and the additional Rails 8.0 combination.
The candidate [Docs run 39178199023](https://github.com/yorzi/ruby_llm-browser/actions/runs/39178199023)
also completed successfully.

The earlier `V0_2_VALIDATION.md` remains a historical snapshot of local candidate
acceptance. Its artifact hash identifies that candidate, not the final release artifact.
The release preparation updates README, released metadata, changelog, What's New,
upgrade instructions, release history, and roadmap status before the tag.

## Final release verification

Release source: `6a5327a80db4d16b0b19d8c1e38f6b30dc7991ed`.
Annotated tag: `v0.2.0`, pointing at that exact commit. The prior `v0.1.0` tag was not moved.

[Final CI run 39178357479](https://github.com/yorzi/ruby_llm-browser/actions/runs/39178357479)
passed all nine jobs on the release commit. Each of the seven compatibility jobs
reports **325 examples, 0 failures**; remote Chrome reports **4 examples, 0 failures**.
The package job reports `CORE_PACKAGE_PASS`, `CLEAN_RUNTIME_ADVISORIES_PASS`, and
`RAILS_PACKAGE_PASS`. Its fixture screenshots were downloaded under
`tmp/remote-ci-0.2.0/` and the mobile recovery and offline Doctor images were inspected.

[Release run 39178482245](https://github.com/yorzi/ruby_llm-browser/actions/runs/39178482245)
passed both tagged verification and RubyGems publication. It used the existing OIDC
trusted publisher and created the public, non-draft, non-prerelease
[GitHub Release](https://github.com/yorzi/ruby_llm-browser/releases/tag/v0.2.0).
Publication completed at 2026-10-18 23:57:13 UTC, which is 2026-10-19 07:57:13 Asia/Shanghai.

RubyGems lists [ruby_llm-browser 0.2.0](https://rubygems.org/gems/ruby_llm-browser/versions/0.2.0).
Its version-specific API metadata, the downloaded GitHub gem, and `SHA256SUMS` agree:

`14b65bae580eb26f6cbc3eafb8031eb18928e4bc303cce788fc01a725af6cd4f`

`PUBLISHED_SOURCE_MATCH_PASS files=88` confirms the published package manifest and
every packaged file's bytes match the release source. This is not a reproducible-build
claim across platforms or a claim that the earlier local candidate had this checksum.
The publication assets and API snapshots are retained under ignored `tmp/release-0.2.0/`.

## Documentation deployment

[Post-release Docs run 39178623905](https://github.com/yorzi/ruby_llm-browser/actions/runs/39178623905)
completed build and deployment successfully. Direct HTTPS checks and an IAB visual
review of the [stable site](https://rubyllm-browser.wangyaodi.com/) confirm:

- The version selector shows `0.2.0 (stable)`.
- The installation command is `bundle add ruby_llm-browser --version "~> 0.2.0"`.
- [What's New in 0.2](https://rubyllm-browser.wangyaodi.com/whats-new-in-0-2/)
  explains the read-only tool factory and backend-aware Doctor.
- The [upgrade guide](https://rubyllm-browser.wangyaodi.com/upgrading/) covers 0.1.0
  to 0.2.0 without a database migration, and `llms.txt` identifies the stable version.

The local tagged documentation build also passed **7,240 links, zero broken**.
Docs lint has zero errors and four reviewed warnings for GitHub-readable legacy
Markdown pointers. Screenshot: `tmp/release-0.2.0/stable-docs.png`.

## Scope and cleanup

README, dated changelog, release history, What's New, upgrade instructions, and
roadmap status are synchronized. Internal candidate/release evidence is excluded
from the gem and public documentation site. The browser review tab is closed; no
local preview service was started for this release turn. Workflow watchers ended.

Version 0.2.0 is published. The current product remains offline-only: Stagehand and
live Act are unsupported, and no live egress, TTL, cleanup, or billing qualification
was performed. No 0.3.0 development is included in this release.
