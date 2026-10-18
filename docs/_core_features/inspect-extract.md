---
layout: default
title: Inspecting and extracting
nav_order: 1
description: Inspect allowlisted pages and extract data with a host-pinned JSON Schema.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* What Inspect returns and what it does not do.
* How Extract uses a schema chosen by the host.
* How tool hashes differ from direct Engine results.

## Create the Read-only Tools

The [offline example in Getting Started]({% link _getting_started/getting-started.md %}) creates a context and a fixed schema. Pass those objects when you construct the tools:

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

The tool returns a `Hash` with string status values. The fake backend used in the linked
example supplies the exact sample output above. In an application, register these tool
instances on a configured RubyLLM chat. The host should select the context and schema;
the model supplies only the URL, optional instruction, and an optional positive
`max_bytes` limit.

## Inspect a Page

`Inspect` navigates to one approved URL and asks the backend for observations. It does
not click, type, submit forms, run arbitrary JavaScript, or download files. Its
observations can still contain hostile instructions, false claims, or sensitive data.
Treat them as untrusted evidence.

## Extract a Known Shape

`Extract` receives its JSON Schema when the host constructs the tool. The model cannot
replace or widen that schema. The policy checks schema size, depth, property count, and
supported keywords. Provider output is validated against the schema before it is
redacted and bounded. A mismatched response is an error, not a successful extraction.

Both tools accept an optional `instruction` to focus the operation and an optional
`max_bytes` value. That value can tighten the policy and remaining operation limit, but
cannot raise either limit. A successful status does not prove that a page claim is true.

## Read the Result

`Tool#execute` and RubyLLM `Tool#call` return hashes. A direct call to `Engine#inspect`
or `Engine#extract` returns a `Result` object. Both forms include status and provenance.
Check the status before consuming data. `truncated` is bounded output, while
`unknown` and `cleanup_pending` need host review.

Do not register `Act` by default. It is a separate experimental tool and live Engine
calls are refused until the same-session host approval protocol is implemented.

## Next Steps

* [Controlling source access]({% link _core_features/source-policy.md %}) - define allowed destinations.
* [Bounding operation work]({% link _core_features/operation-lifecycle.md %}) - set budgets and store lifecycle state.
* [API and configuration reference]({% link _reference/api-reference.md %}) - review fields and error codes.
