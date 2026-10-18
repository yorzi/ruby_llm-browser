---
layout: default
title: Simulating approved actions
nav_order: 4
description: Simulate one host-approved browser action with FakeBackend.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How the host issues and revokes an action grant.
* Which action details the grant binds.
* Why this simulation does not authorize a live browser action.

A model can propose a click, but the host must decide whether that exact action is
allowed. `FakeBackend` lets you exercise that approval flow without opening a browser or
making a network request.

## Issue a Grant and Run the Simulation

Create the approval from the same action and URL that you pass to `Act`. Use host-owned
actor and run identifiers. Do not take those values from model output.

```ruby
require "ruby_llm/browser"

class OfflineResolver
  def getaddresses(_host) = [ "93.184.216.34" ]
end

policy = RubyLLM::Browser::Policy.new(
  allowed_hosts: [ "docs.example.com" ], resolver: OfflineResolver.new
)
approval_store = RubyLLM::Browser::InMemoryApprovalStore.new
context = RubyLLM::Browser::Context.new(
  actor_id: "demo-actor", run_id: "demo-run",
  backend: RubyLLM::Browser::FakeBackend.new,
  source_policy: policy,
  operation_store: RubyLLM::Browser::InMemoryOperationStore.new,
  approval_store: approval_store
)

url = policy.authorize_destination!("https://docs.example.com/").to_s
action = policy.authorize_action!({ "method" => "click", "selector" => "a#docs" })
approval = RubyLLM::Browser::Approval.for_action(
  actor_id: context.actor_id, run_id: context.run_id,
  url: url, action: action, ttl: 60, now: context.now
)
approval_store.issue(approval)

act = RubyLLM::Browser::Act.new(context: context)
result = act.execute(
  url: url, approval_id: approval.id, method: "click", selector: "a#docs"
)

puts result[:status] # => "ok"
puts result.dig(:locator, "approval_id") # => approval.id
```

The example uses one active grant. It does not call a model. `Act` is opt-in and is not
registered by default.

## Bind the Grant to the Request

`Policy#authorize_action!` returns a canonical hash with `description`, `method`,
`selector`, and `arguments`. The method is lowercase. Empty descriptions default to
`"#{method} #{selector}"`; arguments are strings. A grant digest uses sorted-key,
compact JSON for this normalized hash. The URL is the exact authorized URL returned by
`Policy#authorize_destination!(url).to_s`.

The host creates the grant with `Approval.for_action` and stores it with
`ApprovalStore#issue`. It can revoke the grant with `ApprovalStore#revoke(id)` before
the action consumes it. A grant expires when `now >= expires_at`. It cannot authorize a
different actor, run, URL, or normalized action. Reads by the tool's resolver do not
consume it. `consume_once` checks and marks the grant consumed atomically immediately
before FakeBackend records the action.

If two calls compete for one valid grant, one returns `ok`, one returns `APPROVAL_STALE`,
and FakeBackend records one action. A durable store must preserve this result across
workers and database connections. `InMemoryApprovalStore` is process-local; use a
durable store for a multi-worker host.

## Read Denial Results

| Condition | Result |
| --- | --- |
| The context has no approval store or the ID is unknown | `APPROVAL_REQUIRED` |
| The grant expired, was revoked or consumed, or does not match the request | `APPROVAL_STALE` |
| Policy denies the action or URL | `NOT_AUTHORIZED` |

Each denial records no simulated action. Check the returned `status` and `error.code`
before using a result.

## Know the Boundary

The fake backend records an in-process action fixture. It does not click a page, change a
website, or prove live authorization. First-release grants leave `page_revision`,
`operation_id`, and `session_id` unset. The full live Act protocol needs a grant bound to
the current page target and browser session; it is deferred to a later version. See
[the security model]({% link SECURITY_MODEL.md %}) and [provider qualification]({% link _advanced/live-backend-qualification.md %}).

## Next Steps

* [Inspect and extract]({% link _core_features/inspect-extract.md %}) - read and structure offline page observations.
* [Control source access]({% link _core_features/source-policy.md %}) - define the host allowlist.
* [Review the operation lifecycle]({% link _core_features/operation-lifecycle.md %}) - handle reservations and cleanup states.
