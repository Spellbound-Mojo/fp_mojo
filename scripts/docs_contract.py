"""Documentation inventories and rendering; no MkDocs or CLI dependency."""
import json
import posixpath
import re
from pathlib import Path

from export_contract import audit_exports
from fp_tools.runtime import ROOT
from module_layout import PUBLIC_PACKAGES
from api_reference import package_markdown

CONTENT = ROOT / 'docs/content'
EXAMPLES = ROOT / 'docs/examples'
DIRECTIVE = re.compile(r'<!--\s*(api|example|source):\s*([^>]*?)\s*-->')
FENCE = re.compile(r'(^```[^\n]*\n.*?^```[ \t]*$)', re.M | re.S)


def data(name):
    return json.loads((ROOT / 'docs' / name).read_text())


def relative(page, destination):
    return posixpath.relpath(destination, posixpath.dirname(page) or '.')


def example_markdown(key, page):
    spec = data('examples.json')['examples'][key]
    code = (ROOT / key).read_text().rstrip()
    source = relative(page, 'downloads/' + key)
    return (f'[Download the complete program]({source}). From the repository root:\n\n'
            f'```sh\npixi run mojo run -I src {key}\n```\n\n'
            f'```mojo\n{code}\n```\n\nExpected standard output:\n\n```text\n{spec["stdout"].rstrip()}\n```\n')


def source_markdown(key, page):
    """Show a maintained example file that is not run on its own (a module or a device program)."""
    code = (ROOT / key).read_text().rstrip()
    source = relative(page, 'downloads/' + key)
    return f'[Download `{posixpath.basename(key)}`]({source}).\n\n```mojo\n{code}\n```\n'


def package_page(package, page):
    def page_of(owner, name):
        return relative(page, f'reference/{owner}.md') + '#' + name
    def source_of(provider):
        return relative(page, f'downloads/src/fp/{provider}.mojo')
    return package_markdown(package, data('api.json'), page_of, source_of)


def render_markdown(text, page):
    def replace(match):
        kind, value = match.groups()
        if kind == 'api':
            assert value in PUBLIC_PACKAGES, f'Unknown API package: {value}'
            return package_page(value, page)
        if kind == 'example':
            return example_markdown(value, page)
        return source_markdown(value, page)
    return ''.join(part if index % 2 else DIRECTIVE.sub(replace, part)
                   for index, part in enumerate(FENCE.split(text)))


def api_problems(package, api):
    from api_reference import primaries
    problems = []
    if not api['packages'][package]['summary']:
        problems.append('package docstring')
    def check(label, overloads):
        if not all(o['summary'] for o in overloads):
            problems.append(f'{label}: an overload without a summary line')
        for o in primaries(overloads):
            problems.extend(f'{label}: parameter {p["name"]}' for p in o['parameters'] if not p['description'])
            problems.extend(f'{label}: argument {a["name"]}' for a in o['args'] if not a['description'])
            if o['returns'] and o['returns']['type'] not in ('', 'None') and not o['returns']['doc']:
                problems.append(f'{label}: return value')
            if o['raises'] and not o['raises_doc']:
                problems.append(f'{label}: raised error')
    for full, entry in api['entries'].items():
        owner, name = full.split('.', 1)
        if owner != package or entry['provider'].split('/')[0] != package:
            continue
        if entry['kind'] == 'function':
            check(name, entry['overloads'])
            continue
        if not entry['summary']:
            problems.append(f'{name}: summary')
        problems += [f'{name}: parameter {p["name"]}' for p in entry['parameters'] if not p['description']]
        for method, overloads in entry.get('methods', {}).items():
            check(f'{name}.{method}', overloads)
    return problems


def audit_docs():
    reviewed = audit_exports()
    exports = data('public-exports.json')
    modules, examples = [], set()
    pages = sorted(CONTENT.rglob('*.md'))
    for page in pages:
        text = page.read_text()
        assert text.startswith('# '), f'Missing page title: {page}'
        # Executable Mojo comes from maintained files, never drifting copies.
        assert not re.search(r'^```mojo\s*$', text, re.M), f'Use an example directive: {page}'
        outside_fences = ''.join(FENCE.split(text)[::2])
        for kind, value in DIRECTIVE.findall(outside_fences):
            if kind == 'api':
                modules.append(value)
            elif kind == 'example':
                examples.add(value)
            elif kind == 'source':
                path = ROOT / value
                assert path.is_file() and path.suffix == '.mojo' and path.is_relative_to(EXAMPLES), \
                    f'Source directive must name a file in docs/examples: {page}: {value}'
    # Every public package has one reference page rendered from its docstrings.
    assert sorted(modules) == sorted(PUBLIC_PACKAGES), 'API package pages differ from the public packages'
    api = data('api.json')
    assert set(api['entries']) == set(exports['exports']), 'docs/api.json is stale; run python scripts/api_docs.py'
    for package in modules:
        problems = api_problems(package, api)
        assert not problems, f'Undocumented API in fp.{package}:\n  ' + '\n  '.join(problems)
    manifest = data('examples.json')['examples']
    assert examples == set(manifest), 'Unused or missing executable example'
    for name, spec in manifest.items():
        assert (ROOT / name).is_file() and name.endswith('.mojo')
        assert isinstance(spec['stdout'], str) and spec['stdout'].endswith('\n')
    return dict(pages=len(pages), exports=reviewed['exports'], modules=len(exports['modules']),
                packages=len(modules), examples=len(examples))
