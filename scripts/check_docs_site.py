#!/usr/bin/env python3
"""Check built guide/API links and keep local evidence out of the public site."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit
import os
import re

root = Path(os.environ.get("SITE", "docs/_site")).resolve()
config = Path("docs/_config.yml").read_text()
match = re.search(r'^baseurl:\s*["\']?([^"\'\n]*)', config, re.M)
base = os.environ.get("BASE", match.group(1).strip() if match else "").rstrip("/")


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        key = "href" if tag in ("a", "link") else "src"
        if tag in ("a", "link", "script", "img") and attrs.get(key):
            self.links.append(attrs[key])


pages = list(root.rglob("*.html"))
if not pages or not (root / "index.html").is_file():
    raise SystemExit("Missing documentation build; run docs/bin/build.sh first")
checked = 0
missing = []
for page in pages:
    parser = Links()
    parser.feed(page.read_text())
    for link in parser.links:
        url = urlsplit(link)
        if url.scheme or url.netloc or not url.path:
            continue
        path = unquote(url.path)
        if base and path.startswith(base + "/"):
            target = root / path[len(base) + 1:]
        elif path.startswith("/") and not base:
            target = root / path.lstrip("/")
        elif path.startswith("/"):
            continue
        else:
            target = page.parent / path
        if target.is_dir():
            target /= "index.html"
        checked += 1
        if not target.exists():
            missing.append((str(page.relative_to(root)), link))
print({"local_links_checked": checked, "broken_count": len(missing), "broken": missing[:30]})
if missing:
    raise SystemExit(1)
for output in (root, root / "next", *root.glob("v[0-9]*")):
    if (output / "evidence").exists():
        raise SystemExit(f"Local evidence published: {output / 'evidence'}")
print("Documentation links and evidence exclusion: PASS")
