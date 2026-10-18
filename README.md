# ruby_llm-browser

An **unofficial community extension** for [RubyLLM](https://rubyllm.com), with an
experimental adapter for the official [Stagehand Ruby SDK](https://github.com/browserbase/stagehand-ruby).
It provides read-only `Inspect` and schema-pinned `Extract` tools, operation bookkeeping,
and an optional Rails 8 adapter. It does not implement a browser engine.

The first release supports the offline `FakeBackend` only. `StagehandBackend` is present
for future qualification, but it refuses live operations until browser-side egress and
provider cleanup are qualified.

> **Pre-release, not approved for publication or production use.** Offline tests pass,
> but browser-side egress, live-provider behavior, and the full session-bound Act
> approval protocol are not qualified. See the [release audit](docs/RELEASE_AUDIT.md).
> This project is not maintained or endorsed by RubyLLM or Browserbase.

## Install from this checkout

The gem has not been published to RubyGems. For development:

```ruby
# Your application's Gemfile
gem "ruby_llm-browser", path: "/path/to/ruby_llm-browser"
```

The core requires Ruby 3.2+, RubyLLM `>= 2.0, < 3`, `json_schemer ~> 2.5`, and
`stagehand ~> 3.21.0`, plus patched DNS/URL/CGI/compression gems (see the
[dependency reference](docs/API.md)). Requiring `ruby_llm/browser` loads neither Rails nor the Stagehand
client, discovers no provider credentials, and opens no browser session.

## Try it offline

This complete example makes no network request and requires no API key:

```ruby
# smoke-test: offline
require "ruby_llm/browser"

# Fake DNS is only for this offline demonstration. Production uses real DNS.
class OfflineResolver
  def getaddresses(_host) = [ "93.184.216.34" ]
end

context = RubyLLM::Browser::Context.new(
  actor_id: "demo-actor", run_id: "demo-run",
  backend: RubyLLM::Browser::FakeBackend.new,
  source_policy: RubyLLM::Browser::Policy.new(
    allowed_hosts: [ "docs.example.com" ], resolver: OfflineResolver.new
  ),
  operation_store: RubyLLM::Browser::InMemoryOperationStore.new
)
schema = {
  "type" => "object",
  "properties" => { "title" => { "type" => "string" } },
  "required" => [ "title" ], "additionalProperties" => false
}

inspect_tool = RubyLLM::Browser::Inspect.new(context: context)
extract_tool = RubyLLM::Browser::Extract.new(context: context, schema: schema)
puts inspect_tool.execute(url: "https://docs.example.com/")[:status] # => ok
puts extract_tool.execute(url: "https://docs.example.com/")[:data]   # => {"title"=>"Example"}
```

Register these instances on your configured RubyLLM chat with
`chat.with_tools(inspect_tool, extract_tool)`. Never register `Act` by default.
The host supplies authenticated **string** actor/run IDs, authorization, consent,
the pinned extraction schema, budgets, and the backend.

The tools return a **Hash**, not a `Result` object. Direct `Engine` calls return a
`Result`. Check `status` and `error`; page data is untrusted evidence, not verified truth.

## Safety boundaries

- URL policy checks hosts, schemes, ports, and public DNS/IP addresses. It cannot
  sandbox a remote browser or control page-triggered requests.
- No built-in live backend is supported in this release. `StagehandBackend` always
  reports egress as unverified and refuses live operations. A host assertion cannot
  enable it.
- The model cannot increase the host's output limit. Results are redacted, schema-checked
  for extraction, and bounded by the policy and remaining operation bytes.
- A durable operation is claimed before start. Duplicate jobs cannot start it again.
  SDK retries are disabled; uncertain outcomes are never automatically replayed.
- Cancellation fences workers but cannot undo an in-flight request. Dispatched operations
  retain quota until cleanup is confirmed. Run a reaper independently of job workers.
- `max_cost_usd` is advisory metadata, not an enforced billing cap. Provider timeouts and
  cleanup are also not a promise of zero future charges.
- `Act` is an offline simulation only. The full same-session live approval protocol is
  deferred to a later version. Candidate-list hashes and selector keyword filters are
  not proof of target identity or action safety.

## Rails integration

Add Rails 8's `activerecord` and `activejob` to your host application, then opt in:

```ruby
require "ruby_llm/browser/rails"
```

```bash
bin/rails generate ruby_llm:browser:install
bin/rails db:migrate
```

The adapter provides durable operation/approval stores, actor-scoped jobs, cancellation,
and a reaper. Follow the [Rails guide](docs/RAILS.md) for the context factory, matching
budgets, status access, scheduling, and upgrading an earlier development database.
Only SQLite concurrency is tested locally; PostgreSQL requires its own qualification.

## Documentation

- [Documentation website](https://rubyllm-browser.wangyaodi.com) (GitHub Pages)
- [Documentation index](docs/README.md)
- [API, configuration, and result reference](docs/API.md)
- [Rails jobs and recovery](docs/RAILS.md)
- [Security model and live qualification](docs/SECURITY_MODEL.md)
- [Compatibility and release checklist](docs/RELEASING.md)
- [Audit findings and unresolved blockers](docs/RELEASE_AUDIT.md)
- [Requirement evidence](docs/WORK.md)
- [Offline scripts](examples/)

These documents and examples are included in the built gem.

## Development

```bash
bin/setup
bundle exec rake
bundle exec bundle-audit check --update
bundle exec ruby examples/plain_ruby.rb
bundle exec ruby examples/rails_adapter.rb
bundle exec rake build
bundle exec ruby bin/verify-package --rails --audit
```

Tests block unmocked network requests. No paid live call or RubyGems publication is part
of the default workflow. See [contributing](CONTRIBUTING.md).

## License

MIT. See [LICENSE.txt](LICENSE.txt) and [third-party notices](NOTICE.md).
