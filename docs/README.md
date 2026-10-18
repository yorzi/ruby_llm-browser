# Documentation

Read the [documentation site](https://rubyllm-browser.wangyaodi.com/) for the latest
stable release. The [next-version site](https://rubyllm-browser.wangyaodi.com/next/)
follows `main`. The Markdown files below are the source for those guides and ship in
the gem.

- [Getting started](_getting_started/getting-started.md): installation and an offline example.
- [Configuration](_getting_started/configuration.md): host inputs and process defaults.
- [Inspect and Extract](_core_features/inspect-extract.md): tools and result handling.
- [Rails jobs and recovery](_advanced/rails-integration.md): installation, workers, and cleanup.
- [API and configuration reference](_reference/api-and-configuration.md): parameters and errors.
- [Security model](SECURITY_MODEL.md): guarantees and limits.
- [Roadmap to 1.0](_reference/roadmap.md): proposed versions and acceptance criteria.

## Maintaining these docs

Keep the root README to installation, one example, and links. Put usage and API details
in the site guides, editing each topic in one place. Link to those source files when
writing repository Markdown; use Jekyll link tags between site pages. Keep
[CHANGELOG.md](../CHANGELOG.md) to shipped changes.

Preview with `docs/bin/serve.sh`; build with `docs/bin/build.sh`. See
[releasing](RELEASING.md) for package checks. The [0.1.0 audit](RELEASE_AUDIT.md),
[release record](RELEASE_ACTION_PLAN.md), [evidence ledger](WORK.md), and
[specification baseline](SPEC_BASELINE.md) preserve historical evidence.
