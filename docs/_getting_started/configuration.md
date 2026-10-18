---
layout: default
title: Configuration
nav_order: 3
description: Set process defaults while keeping identity, authorization, schemas, and credentials in the host.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* Which process-wide defaults RubyLLM::Browser can hold.
* Which trusted values belong in each `Context` and `Policy`.
* Why backend credentials and extraction schemas stay outside model arguments.

## Set Process Defaults

`RubyLLM::Browser.configure` sets defaults for new objects. Existing contexts and
policies keep the values they received when they were created.

```ruby
require "ruby_llm/browser"

RubyLLM::Browser.configure do |config|
  config.default_budget = RubyLLM::Browser::Budget.new(max_seconds: 30, max_steps: 6)
  config.max_result_bytes = 32_768
end

policy = RubyLLM::Browser::Policy.new(allowed_hosts: [ "docs.example.com" ])
```

The gem does not load provider credentials from the environment when you require it.
The host creates the backend and passes it to every context. The `configuration.backend`
slot is reserved for host integration and is not a fallback used by `Context`.

## Choose a Source Policy

Pass exact host names when possible. A pattern such as `*.example.com` allows matching
subdomains but not the bare `example.com` host. The defaults allow HTTP and HTTPS on
ports 80 and 443. DNS verification is enabled by default. Keep it enabled for real use;
inject a resolver only in controlled offline fixtures.

`Policy` also sets `max_result_bytes`, extraction schema limits, and the set of allowed
action methods for the experimental Act path. Browser-side egress must separately cover
redirects, frames, popups, WebSockets, assets, and other subresources.

## Defaults and Ownership

| Setting | Default | Owner |
| --- | --- | --- |
| `default_budget` | 60 seconds, 12 steps, 262,144 bytes, 1 concurrent operation, no cost estimate | Host process |
| `max_result_bytes` | 65,536 bytes | Host process and new policies |
| `clock` | `Time.now.utc` | Host process or context |
| `logger` | RubyLLM logger when present, otherwise a warning-level stderr logger | Host process |
| `backend` | `nil`, unused as a fallback | Host; pass explicitly to `Context` |

`Budget#max_cost_usd` is advisory metadata. It does not enforce provider billing. The
host must also reauthorize the actor and run when creating a context, including from a
background job. For all context and policy options, see the [API and configuration reference]({% link _reference/api-reference.md %}).

## Next Steps

* [Controlling source access]({% link _core_features/source-policy.md %}) - review URL and DNS rules.
* [Bounding operation work]({% link _core_features/operation-lifecycle.md %}) - understand limits and cleanup.
