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

## Point-in-time runtime inventory (2026-10-18)

Resolved locally on Ruby 3.3.5 with RubyLLM 2.1.1. Version ranges can resolve a different
set on a future install. No dependency source is vendored; dependencies are distributed
as separate gems. This metadata inventory is not naming or legal clearance.

| Dependency | Version | Declared license(s) |
| --- | --- | --- |
| ruby_llm | 2.1.1 | MIT |
| stagehand | 3.21.0 | No gem metadata; pinned source MIT text below |
| json_schemer | 2.5.0 | MIT |
| hana | 1.3.7 | MIT |
| simpleidn | 0.3.0 | MIT |
| regexp_parser | 2.13.1 | MIT |
| schematist | 1.1.0 | MIT |
| zeitwerk | 2.8.3 | MIT |
| connection_pool | 3.0.2 | MIT |
| faraday | 2.15.0 | MIT |
| faraday-net_http | 3.5.0 | MIT |
| faraday-multipart | 1.2.0 | MIT |
| faraday-retry | 2.4.0 | MIT |
| multipart-post | 2.4.1 | MIT |
| marcel | 2.1.0 | MIT / Apache-2.0 |
| base64 | 0.3.0 | Ruby / BSD-2-Clause |
| bigdecimal | 4.1.3 | Ruby / BSD-2-Clause |
| cgi | 0.5.2 | Ruby / BSD-2-Clause |
| json | 3.1.0 | Ruby |
| logger | 1.7.0 | Ruby / BSD-2-Clause |
| net-http | 0.10.0 | Ruby / BSD-2-Clause |
| net-protocol | 0.4.0 | Ruby / BSD-2-Clause |
| timeout | 0.6.1 | Ruby / BSD-2-Clause |
| uri | 1.1.2 | Ruby / BSD-2-Clause |
| resolv | 0.8.1 | Ruby / BSD-2-Clause |
| zlib | 3.2.4 | Ruby / BSD-2-Clause |

Rails/Active Record/Active Job are optional host dependencies (MIT); sqlite3 is a test/
host adapter (BSD-3-Clause). Development-only dependencies are not gem runtime requirements.

## Stagehand pinned source license text

Source: <https://github.com/browserbase/stagehand-ruby/blob/v3.21.0/LICENSE>, fetched
2026-10-18. Included because the published Stagehand 3.21.0 gem omits the license file.

Copyright 2026 stagehand

Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files (the "Software"), to deal in the Software
without restriction, including without limitation the rights to use, copy, modify,
merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be included in all copies
or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
