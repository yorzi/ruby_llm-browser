# Third-party notices

`ruby_llm-browser` is MIT licensed (see `LICENSE.txt`). It builds on the following
upstream projects. No upstream code is vendored into this Gem; the notices below
exist so downstream installs can reproduce the full license chain.

## RubyLLM (`ruby_llm`)

- License: MIT
- Source: <https://github.com/crmne/ruby_llm>
- Used for: the `RubyLLM::Tool` protocol and the chat tool-execution loop.

## Stagehand Ruby SDK (`stagehand`)

- License: MIT, as declared in the repository `LICENSE` file, "Copyright 2026 stagehand"
  (`https://github.com/browserbase/stagehand-ruby/blob/v3.21.0/LICENSE`).
- Source tag: `v3.21.0` (commit `b389c6e3ca7e4a5f9d46511082a6466d37163e17`).
- Used for: the reference browser REST client behind
  `RubyLLM::Browser::StagehandBackend`.
- Note: the published `stagehand` gem ships without license metadata and without the
  `LICENSE` file, so this notice cites the repository license at the pinned tag. Pin
  the exact version and checksum in your `Gemfile.lock`.

## Transitive dependencies

`ruby_llm`, `stagehand`, and their transitive dependencies may carry other licenses
(`faraday`, `zeitwerk`, `schematist`, `connection_pool`, `cgi`, and so on). Audit them
for your own distribution; this file does not replace that audit.
