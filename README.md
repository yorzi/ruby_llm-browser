# ruby_llm-browser

**Unofficial community extension for [RubyLLM](https://rubyllm.com).**
Policy-bound browser `Inspect` and `Extract` tools for RubyLLM agents, backed by the
official [Stagehand Ruby SDK](https://github.com/browserbase/stagehand-ruby), with an
opt-in human-approved `Act` tool and an optional Rails 8 / Active Job adapter.

> This is **not** an official RubyLLM project. The `RubyLLM` namespace is used to match
> community convention (`ruby_llm-<feature>`); it does not imply RubyLLM core ownership,
> endorsement or trademark rights. Names, licenses and live-browser guarantees are not
> claimed until verified — see [Status](#status).

## Why

RubyLLM already gives you the Tool protocol and the chat loop. Stagehand's Ruby SDK
already gives you typed browser sessions. What is missing is the reusable, easy-to-get-
wrong layer between them:

- composable **source and egress policy** (allowlists, SSRF/redirect/DNS-rebinding
  defense, fail-closed when a backend cannot enforce egress),
- **bounded, sanitized, attributed results** instead of raw page dumps,
- **durable operation and session lifecycle** (`reserved → starting → active → closing
  → closed`, plus `unknown` / `cleanup_pending`) that survives worker retries and death,
- **budgets, cancellation and cleanup**,
- **per-action human approval** bound to the exact page and action,
- optional **Rails 8 Active Job** integration.

It deliberately does **not** reimplement a browser engine, port Browser Use, or expose a
generic autonomous side-effect tool.

## Install

```ruby
# Gemfile
gem "ruby_llm-browser"
```

```ruby
require "ruby_llm"
require "ruby_llm/browser"
```

The Gem core is plain Ruby. Requiring it does not load Rails, read SDK credentials or
open any session.

## Usage (illustrative)

The host application — not the model and not page text — supplies identity, consent,
source policy and the backend.

```ruby
policy = RubyLLM::Browser::Policy.new(
  allowed_hosts: ["docs.example.com", "*.example.org"]
)

context = RubyLLM::Browser::Context.new(
  actor_id: current_user.id,
  run_id: research_run.id,
  source_policy: policy,
  backend: RubyLLM::Browser::StagehandBackend.new(
    browserbase_api_key: ENV.fetch("BROWSERBASE_API_KEY"),
    model_api_key: ENV.fetch("MODEL_API_KEY"),
    model_name: "gpt-4.1-mini",
    egress_isolated: true # only after you qualified the provider's isolation
  ),
  operation_store: RubyLLM::Browser::InMemoryOperationStore.new, # durable store in production
  budget: RubyLLM::Browser::Budget.new(max_seconds: 60, max_steps: 12)
)

chat = RubyLLM.chat.with_tools(
  RubyLLM::Browser::Inspect.new(context: context),
  RubyLLM::Browser::Extract.new(context: context)
  # Never register RubyLLM::Browser::Act by default.
)
```

Every tool returns a bounded `RubyLLM::Browser::Result` with `status`, `final_url`,
`captured_at`, a content `digest`/`locator`, a truncation flag and a typed `error_code`.
Page text is untrusted evidence, never instructions, and a successful result never
verifies the truth of extracted claims.

## Status

This Gem is under active development ahead of any public release. What follows is a
deliberately honest split between "implemented and tested offline" and "not proven".

| Area | State |
| --- | --- |
| Gem scaffold, Ruby-only fixture, CI | done |
| Read-only `Inspect` / `Extract` core (fake backend) | in progress |
| URL/SSRF policy and fail-closed egress gate | in progress |
| Stagehand adapter, durable operation store, budgets | planned |
| Opt-in `Act` with one-use approvals, Rails 8 jobs | planned |
| Live provider smoke test | **not run** — requires explicit owner authorization |
| Public RubyGems release | **blocked** pending name/license/security/compatibility clearance |

Mocked or fake backends prove the Gem's API logic only. They never prove a provider's
remote network egress isolation, TTL or billing limits. See
[`docs/SPEC_BASELINE.md`](docs/SPEC_BASELINE.md) and
[`docs/SECURITY_MODEL.md`](docs/SECURITY_MODEL.md).

## Non-goals

No browser engine, no Browser Use port, no arbitrary JS/shell tool, no CAPTCHA/age/access
bypass, no credential or cookie scraping, no purchases, posting or account changes, no
hidden paid fallback on load.

## Compatibility targets (not yet proven)

| Component | Target |
| --- | --- |
| Ruby | >= 3.2 |
| RubyLLM | 2.0.0 and 2.1.x (tool core required) |
| Stagehand | 3.21.0 (tag `v3.21.0`) |
| Rails / Active Job | 8.x, optional |

## Development

```bash
bin/setup
bundle exec rake
```

Default CI uses fakes only. Live browser tests are opt-in and owner-authorized.

## License

MIT — see [`LICENSE.txt`](LICENSE.txt) and [`NOTICE.md`](NOTICE.md) for upstream notices.
