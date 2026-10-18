# AGENTS.md

## Development and verification

- Use `bin/check` for the offline suite, lint, supported alternate bundles, and examples.
  Run database suites sequentially. Add a failing public-contract test before changing behavior.
- `dev/workbench.rb` is the single maintained offline browser fixture. Use `bin/workbench`
  for manual review and `bin/check-browser` for Chrome E2E tests and screenshots.
  Browser dependencies stay in `gemfiles/browser.gemfile`, outside runtime dependencies.
- For UI changes, inspect success and failure screenshots, plus keyboard and mobile behavior.
  A screenshot is review evidence, not an assertion. Convert reproduced failures into tests.
- For release candidates, run `bin/check --browser --package` and build the docs.
  Record exact results and untested boundaries in the candidate validation note.
- Bind task-owned services and driver probes to loopback. Stop all task-owned servers,
  browsers, drivers, and watchers before finishing. Never pass credentials in process arguments.
- Offline fixture results do not qualify live browser egress, cleanup, TTL, or billing.

## Docs

The documentation site lives in `docs/`: Jekyll with the jekyll-vitepress-theme, in four collections (`_getting_started`, `_core_features`, `_advanced`, `_reference`). Preview it with `docs/bin/serve.sh` and build it with `docs/bin/build.sh`.

- A public API change is not done until its docs page changes in the same commit. Record anything that breaks existing code in `docs/_reference/upgrading.md`.
- Write in the Rails guides voice: second person, present tense, short sentences, code first, and the problem before the mechanics. No em dashes, no hype, no "simply".
- Every guide opens with its title, its description, and "After reading this guide, you will know". Explain a concept before summarizing it in a table.
- Start with the shortest working example, then options, then integration and backend-specific notes. Document a shared API once.
- Give each standalone feature a discoverable guide, and feature new ones on the release's What's New page.
- Front-matter `description` is one sentence and feeds llms.txt and link previews. Never use `&`, `<`, or `>` in it.
- Cross-link with `{% link _collection/page.md %}`, never hard-coded URLs. Keep values that change between releases in `_config.yml` and read them as `site.*` variables.
- Never edit generated pages; regenerate them.
- Public methods and classes get doc comments; mark internal code as internal.
