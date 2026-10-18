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

## Publication status

Release preparation is in progress. The final commit, tag, publication workflow,
artifact checksum, and stable documentation verification will be recorded after the
remote release completes. No publication success is inferred from a green candidate CI.
