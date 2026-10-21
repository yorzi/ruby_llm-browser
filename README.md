# ruby_llm-browser

An unofficial [RubyLLM](https://rubyllm.com) extension for read-only browser inspection
and schema-checked extraction, with an optional Rails 8 adapter.

**0.4.4 supports offline use only.** `FakeBackend` runs without credentials or network
requests. The experimental Stagehand adapter refuses live operations; `Act` is an
offline simulation. This project is not maintained or endorsed by RubyLLM or Browserbase.

[Documentation](https://rubyllm-browser.wangyaodi.com/) ·
[Getting started](https://rubyllm-browser.wangyaodi.com/getting-started/) ·
[Roadmap to 1.0](docs/_reference/roadmap.md)

## Install

Use Ruby 3.2+ and RubyLLM 2.x. Add to your Gemfile, then run `bundle install`:

```ruby
gem "ruby_llm-browser", "~> 0.4.4"
```

## Try it offline

```ruby
# smoke-test: offline
require "ruby_llm/browser"

# Test resolver for this offline example only.
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
  "type" => "object", "properties" => { "title" => { "type" => "string" } },
  "required" => [ "title" ], "additionalProperties" => false
}
inspect_tool, extract_tool = RubyLLM::Browser.tools(context: context, schema: schema)
puts inspect_tool.execute(url: "https://docs.example.com/")[:status] # => ok
puts extract_tool.execute(url: "https://docs.example.com/")[:data]   # => {"title"=>"Example"}
```

Register these tools on your configured chat with
`chat.with_tools(inspect_tool, extract_tool)`. The host owns identity, authorization,
source policy, schema, and budgets. Tool calls return hashes; page data remains untrusted.

## Learn more

Use the [documentation site](https://rubyllm-browser.wangyaodi.com/) for configuration,
Rails jobs, API details, and security boundaries. The same guides ship as Markdown in
the gem; [docs/README.md](docs/README.md) indexes their source files.

## Contributing

Run `bin/setup`, then `bundle exec rake`. Tests block unmocked network requests.
See [CONTRIBUTING.md](CONTRIBUTING.md) for development and
[the roadmap](docs/_reference/roadmap.md) for the next iterations.

## License

[MIT](LICENSE.txt). See [third-party notices](NOTICE.md).
