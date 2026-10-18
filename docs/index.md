---
layout: home
title: "RubyLLM::Browser"
description: "An unofficial RubyLLM extension for offline bounded browser inspection and schema-checked extraction."
permalink: /
hero:
  name: "RubyLLM::Browser"
  text: "Policy-bound browser tools for RubyLLM"
  tagline: "An unofficial RubyLLM extension for offline bounded browser inspection and schema-checked extraction."
  actions:
    - theme: brand
      text: Get started
      link: /getting-started/
    - theme: alt
      text: View on GitHub
      link: https://github.com/yorzi/ruby_llm-browser
features:
  - title: "Read-only by default"
    details: "Inspect and Extract do not dispatch browser actions, and page content remains untrusted evidence."
    link: /inspect-extract/
    link_text: Inspect and extract
  - title: "Host-controlled access"
    details: "The host supplies identity, URL policy, schemas, budgets, and consent. Live Stagehand use is disabled."
    link: /source-policy/
    link_text: Control source access
  - title: "Bounded operation state"
    details: "Track lifecycle and cap time, steps, concurrent operations, and retained result bytes."
    link: /operation-lifecycle/
    link_text: Bound operation work
---

## Before You Install

This gem has not been published to RubyGems. Install the unreleased source from GitHub.
A version such as `0.1.0` in the source tree is not a claim that a public release exists.
The first release supports only the offline `FakeBackend`. The built-in Stagehand adapter
is unsupported until provider egress and confirmed cleanup are qualified. Live Act is
deferred to a later version.

## Install

```sh
{% if site.docs_unreleased %}bundle add ruby_llm-browser --git https://github.com/yorzi/ruby_llm-browser --branch main{% else %}bundle add ruby_llm-browser --git https://github.com/yorzi/ruby_llm-browser --ref v{{ site.version }}{% endif %}
```

## A First Look

This offline example makes no network request and needs no API key.

```ruby
require "ruby_llm/browser"

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

The fake backend proves only that the Ruby API can run offline. It says nothing about a
real browser provider's egress, session cleanup, or billing. Read [the security model]({% link SECURITY_MODEL.md %}) before evaluating a live backend.

[Get started]({% link _getting_started/getting-started.md %}) or read [how the gem works]({% link _getting_started/overview.md %}).
