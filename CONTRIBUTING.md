# Contributing to ruby_llm-browser

Thanks for helping. This is an unofficial community extension for
[RubyLLM](https://rubyllm.com), not an official RubyLLM project.

## Ground rules

1. **Fail closed.** Anything that touches URLs, egress, sessions, approvals, budgets or
   secrets must default to deny and must be provable by a test.
2. **No new unsafe surface.** No arbitrary JS/shell, no credential or cookie scraping,
   no CAPTCHA/age/access bypass, no purchases, posting or account changes, and no
   second browser engine.
3. **Offline by default.** CI must never make a paid provider call. Use the fake backend
   or an injected client. Live tests are opt-in and owner-authorized.
4. **Say what is not proven.** Distinguish PASS from NOT RUN. Mocked egress proves the
   Gem's logic, never a provider's network isolation.

## Development

```bash
bin/setup          # bundle install
bundle exec rake   # specs + rubocop
bundle exec rspec  # specs only
bundle exec bundle-audit check --update
bundle exec rubocop -A   # autocorrect style
```

## Changing behaviour

- Add a failing spec first, including the negative/denial case.
- Update `CHANGELOG.md` under `Unreleased`.
- Update `docs/SECURITY_MODEL.md` or `README.md` if a boundary or public API moved.
- Keep runnable examples and the package's local links green in
  `spec/integration/documentation_spec.rb`.
- Run both alternate bundles in `gemfiles/` when changing Tool or Rails integration.
- Keep the Gem core loadable without Rails: `ruby -e 'require "ruby_llm/browser"'` must
  not load `rails`, `active_job` or open any browser session.

## Pull requests

Keep commits small and focused. Explain the security impact of the change, list the
tests you ran, and note anything you could not verify. Maintainers control releases.
