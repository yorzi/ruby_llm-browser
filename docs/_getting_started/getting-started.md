---
layout: default
title: Getting Started
nav_order: 1
description: Install the unreleased source gem and run a read-only operation with its offline backend.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to install the current source version.
* How to run Inspect and Extract without a provider or network request.
* Where to review live-provider limitations.

## Installation

The gem is not published to RubyGems. Install it from the default branch:

```sh
bundle add ruby_llm-browser --git https://github.com/yorzi/ruby_llm-browser --branch main
```

Use Ruby 3.2 or later. The gem supports RubyLLM `>= 2.0, < 3` and pins Stagehand to the
3.21.x series. Rails is optional and is not loaded by the core entry point. See
[configuration]({% link _getting_started/configuration.md %}) for host-owned settings.

## Run a Read-only Operation Offline

This complete example needs no credentials and makes no network request. Its resolver
returns a public test address so URL policy can be exercised without DNS.

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

`FakeBackend` supplies deterministic responses. Replace it with a host-qualified backend
only after you have reviewed the [security boundaries]({% link _advanced/live-backend-qualification.md %}).

## Next Steps

* [How RubyLLM::Browser Works]({% link _getting_started/overview.md %}) - follow the objects through an operation.
* [Configuration]({% link _getting_started/configuration.md %}) - set process defaults and build a trusted context.
* [Inspecting and extracting]({% link _core_features/inspect-extract.md %}) - register tools and interpret their results.
