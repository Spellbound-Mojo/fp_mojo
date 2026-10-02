"""Build strict MkDocs, then inspect rendered links, assets and search inventory."""
from html.parser import HTMLParser
from pathlib import Path
import json
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit

from docs_contract import audit_docs, CONTENT, DIRECTIVE
from fp_tools.runtime import ROOT


class Page(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.ids = set()
        self.links = []
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs:
            assert attrs['id'] not in self.ids, f'Duplicate HTML id: {attrs["id"]}'
            self.ids.add(attrs['id'])
        for name in ('href', 'src'):
            if name in attrs:
                self.links.append(attrs[name])


def site_prefix():
    """The path the site is served under, from `site_url` (`/fp_mojo/`), or `/`."""
    found = re.search(r'^site_url:\s*(\S+)', (ROOT / 'mkdocs.yml').read_text(), re.M)
    return urlsplit(found[1]).path.rstrip('/') + '/' if found else '/'


def audit_site(site, prefix='/'):
    pages = {p: Page(p.read_text()) for p in site.rglob('*.html')}
    checked = 0
    for path, page in pages.items():
        for link in page.links:
            url = urlsplit(link)
            if url.scheme or url.netloc:
                continue
            if url.path.startswith('/'):
                # Absolute paths, as in the 404 page, start with the served prefix.
                assert url.path.startswith(prefix), f'Link outside the site: {path}: {link}'
                target = (site / unquote(url.path[len(prefix):])).resolve()
            else:
                target = (path.parent / unquote(url.path)).resolve() if url.path else path
            if target.is_dir():
                target = target / 'index.html'
            assert target.is_relative_to(site), f'Link escapes site: {path}: {link}'
            assert target.is_file(), f'Missing site target: {path}: {link}'
            if url.fragment and target in pages:
                assert unquote(url.fragment) in pages[target].ids, f'Missing anchor: {path}: {link}'
            checked += 1
    search = json.loads((site / 'search/search_index.json').read_text())
    indexed = {d['location'].split('#')[0] for d in search['docs']}
    for page in CONTENT.rglob('*.md'):
        if any(kind == 'api' for kind, _ in DIRECTIVE.findall(page.read_text())):
            location = page.relative_to(CONTENT).with_suffix('').as_posix() + '/'
            assert location in indexed, f'Unindexed API topic: {location}'
    return dict(html_pages=len(pages), local_targets=checked, search_documents=len(search['docs']))


def main():
    inventory = audit_docs()
    subprocess.run([sys.executable, '-m', 'mkdocs', 'build', '--strict'], cwd=ROOT, check=True)
    result = dict(passed=True, inventory=inventory, rendered=audit_site((ROOT / '.cache/docs-site').resolve(), site_prefix()))
    print(json.dumps(result, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
