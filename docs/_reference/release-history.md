---
layout: default
title: Release History
nav_order: 9
guide: false
description: Follow release tags and their documentation for RubyLLM::Browser.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

{% if site.docs_unreleased %}The current source build follows `main` for the unreleased
`{{ site.version }}` candidate. The latest stable release is `{{ site.stable_version }}`.
{% else %}This documentation describes the `{{ site.version }}` release. Use the tag and
release notes to identify the exact source for this version.
{% endif %}

| Release | Date | Highlights |
| --- | --- | --- |
| [0.1.0](https://github.com/yorzi/ruby_llm-browser/releases/tag/v0.1.0) | 2026-10-18 | Offline read-only Inspect and Extract, Rails adapter, and Act simulation; live Stagehand and live Act are unsupported |

For changes to existing applications, follow [Upgrading]({% link _reference/upgrading.md %}).
