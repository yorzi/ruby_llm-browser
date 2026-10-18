# Third-party notices

`ruby_llm-browser` is MIT licensed (see `LICENSE.txt`). It declares separate runtime
dependencies; no upstream source code is vendored in this Gem. The inventory below covers
the 26 runtime dependency gems resolved in the local lockfile on 2026-10-18 and matches
their exact installed gemspec license metadata. Stagehand has no license metadata in its
published gem, so its MIT license is tied to the pinned upstream source tag below.

This is a point-in-time technical inventory, not legal advice or trademark, affiliation,
account-ownership, or publication clearance. Version ranges can resolve different
versions later; recheck the exact artifact before distribution.

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

## Point-in-time runtime inventory (2026-10-18)

Resolved locally on Ruby 3.3.5 with RubyLLM 2.1.1. Every dependency row was matched to
the local lockfile version and installed gemspec license metadata. RubyGems version links
identify the exact distributed releases; Stagehand's pinned-source exception is noted
above. Rails/Active Record/Active Job and sqlite3 are host/test dependencies and are not
part of this Gem's runtime dependency graph.

| Dependency | Version | Declared license(s) | RubyGems version record |
| --- | --- | --- | --- |
| [`ruby_llm`](https://rubygems.org/gems/ruby_llm/versions/2.1.1) | 2.1.1 | MIT | [RubyGems version](https://rubygems.org/gems/ruby_llm/versions/2.1.1) |
| [`stagehand`](https://rubygems.org/gems/stagehand/versions/3.21.0) | 3.21.0 | No gem metadata; pinned source MIT text below | [RubyGems version](https://rubygems.org/gems/stagehand/versions/3.21.0) |
| [`json_schemer`](https://rubygems.org/gems/json_schemer/versions/2.5.0) | 2.5.0 | MIT | [RubyGems version](https://rubygems.org/gems/json_schemer/versions/2.5.0) |
| [`hana`](https://rubygems.org/gems/hana/versions/1.3.7) | 1.3.7 | MIT | [RubyGems version](https://rubygems.org/gems/hana/versions/1.3.7) |
| [`simpleidn`](https://rubygems.org/gems/simpleidn/versions/0.3.0) | 0.3.0 | MIT | [RubyGems version](https://rubygems.org/gems/simpleidn/versions/0.3.0) |
| [`regexp_parser`](https://rubygems.org/gems/regexp_parser/versions/2.13.1) | 2.13.1 | MIT | [RubyGems version](https://rubygems.org/gems/regexp_parser/versions/2.13.1) |
| [`schematist`](https://rubygems.org/gems/schematist/versions/1.1.0) | 1.1.0 | MIT | [RubyGems version](https://rubygems.org/gems/schematist/versions/1.1.0) |
| [`zeitwerk`](https://rubygems.org/gems/zeitwerk/versions/2.8.3) | 2.8.3 | MIT | [RubyGems version](https://rubygems.org/gems/zeitwerk/versions/2.8.3) |
| [`connection_pool`](https://rubygems.org/gems/connection_pool/versions/3.0.2) | 3.0.2 | MIT | [RubyGems version](https://rubygems.org/gems/connection_pool/versions/3.0.2) |
| [`faraday`](https://rubygems.org/gems/faraday/versions/2.15.0) | 2.15.0 | MIT | [RubyGems version](https://rubygems.org/gems/faraday/versions/2.15.0) |
| [`faraday-net_http`](https://rubygems.org/gems/faraday-net_http/versions/3.5.0) | 3.5.0 | MIT | [RubyGems version](https://rubygems.org/gems/faraday-net_http/versions/3.5.0) |
| [`faraday-multipart`](https://rubygems.org/gems/faraday-multipart/versions/1.2.0) | 1.2.0 | MIT | [RubyGems version](https://rubygems.org/gems/faraday-multipart/versions/1.2.0) |
| [`faraday-retry`](https://rubygems.org/gems/faraday-retry/versions/2.4.0) | 2.4.0 | MIT | [RubyGems version](https://rubygems.org/gems/faraday-retry/versions/2.4.0) |
| [`multipart-post`](https://rubygems.org/gems/multipart-post/versions/2.4.1) | 2.4.1 | MIT | [RubyGems version](https://rubygems.org/gems/multipart-post/versions/2.4.1) |
| [`marcel`](https://rubygems.org/gems/marcel/versions/2.1.0) | 2.1.0 | MIT / Apache-2.0 | [RubyGems version](https://rubygems.org/gems/marcel/versions/2.1.0) |
| [`base64`](https://rubygems.org/gems/base64/versions/0.3.0) | 0.3.0 | Ruby / BSD-2-Clause | [RubyGems version](https://rubygems.org/gems/base64/versions/0.3.0) |
| [`bigdecimal`](https://rubygems.org/gems/bigdecimal/versions/4.1.3) | 4.1.3 | Ruby / BSD-2-Clause | [RubyGems version](https://rubygems.org/gems/bigdecimal/versions/4.1.3) |
| [`cgi`](https://rubygems.org/gems/cgi/versions/0.5.2) | 0.5.2 | Ruby / BSD-2-Clause | [RubyGems version](https://rubygems.org/gems/cgi/versions/0.5.2) |
| [`json`](https://rubygems.org/gems/json/versions/3.1.0) | 3.1.0 | Ruby | [RubyGems version](https://rubygems.org/gems/json/versions/3.1.0) |
| [`logger`](https://rubygems.org/gems/logger/versions/1.7.0) | 1.7.0 | Ruby / BSD-2-Clause | [RubyGems version](https://rubygems.org/gems/logger/versions/1.7.0) |
| [`net-http`](https://rubygems.org/gems/net-http/versions/0.10.0) | 0.10.0 | Ruby / BSD-2-Clause | [RubyGems version](https://rubygems.org/gems/net-http/versions/0.10.0) |
| [`net-protocol`](https://rubygems.org/gems/net-protocol/versions/0.4.0) | 0.4.0 | Ruby / BSD-2-Clause | [RubyGems version](https://rubygems.org/gems/net-protocol/versions/0.4.0) |
| [`timeout`](https://rubygems.org/gems/timeout/versions/0.6.1) | 0.6.1 | Ruby / BSD-2-Clause | [RubyGems version](https://rubygems.org/gems/timeout/versions/0.6.1) |
| [`uri`](https://rubygems.org/gems/uri/versions/1.1.2) | 1.1.2 | Ruby / BSD-2-Clause | [RubyGems version](https://rubygems.org/gems/uri/versions/1.1.2) |
| [`resolv`](https://rubygems.org/gems/resolv/versions/0.8.1) | 0.8.1 | Ruby / BSD-2-Clause | [RubyGems version](https://rubygems.org/gems/resolv/versions/0.8.1) |
| [`zlib`](https://rubygems.org/gems/zlib/versions/3.2.4) | 3.2.4 | Ruby / BSD-2-Clause | [RubyGems version](https://rubygems.org/gems/zlib/versions/3.2.4) |

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
