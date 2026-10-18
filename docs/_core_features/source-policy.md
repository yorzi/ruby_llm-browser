---
layout: default
title: Controlling source access
nav_order: 2
description: Restrict navigation to approved public hosts, schemes, and ports.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How the host allowlist matches names.
* Which URL checks happen before a backend starts.
* Why a Ruby URL allowlist does not replace browser-side egress control.

## Allow a Destination

The host creates a `Policy` and supplies it through the operation context. Exact host
names make the intended scope clear. This offline check injects a resolver so it makes no
DNS request:

```ruby
require "ruby_llm/browser"

class OfflineResolver
  def getaddresses(_host) = [ "93.184.216.34" ]
end

policy = RubyLLM::Browser::Policy.new(
  allowed_hosts: [ "docs.example.com" ], resolver: OfflineResolver.new
)
puts policy.authorize_destination!("https://docs.example.com/").host
# => "docs.example.com"
```

The default scheme allowlist is HTTP and HTTPS, and the default ports are 80 and 443.
DNS verification is enabled. Public address checks reject loopback, private, link-local,
multicast, documentation, and cloud metadata ranges. A wildcard such as
`*.example.com` matches subdomains and does not allow the bare `example.com` host.

## Keep Host and Browser Policy Aligned

The host allowlist checks the requested destination before navigation. It cannot
sandbox a remote browser. Provider-side enforcement must also cover DNS at connection
time, redirects, frames, popups, WebSockets, scripts, and all other subresources. Pages
can initiate requests even when the gem only observes them.

The backend must report enforced egress isolation before a live session can start.
The built-in `StagehandBackend` always reports `:unverified` and refuses live calls in
the first release. No caller option can override that posture. A custom backend must
provide its own enforceable egress control; a host assertion does not install a firewall
or prove provider behavior. See [backend qualification]({% link _advanced/live-backend-qualification.md %}) before selecting a live backend.

## Next Steps

* [Inspecting and extracting]({% link _core_features/inspect-extract.md %}) - use the read-only tools.
* [Configuration]({% link _getting_started/configuration.md %}) - keep policy and identity host-owned.
* [Security model]({% link SECURITY_MODEL.md %}) - review trust boundaries and open limits.
