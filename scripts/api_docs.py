"""Extract the public API's docstrings into docs/api.json with `mojo doc`.

Docstrings in the source are the API documentation. `mojo doc` parses their
Parameters, Args, Returns and Raises sections; the reviewed export inventory
(docs/public-exports.json) decides which names are public and supplies their
signatures as written in the source. The documentation build has no Mojo
toolchain, so the result is committed; `--check` fails when it is stale.
"""
import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

from fp_tools.runtime import ROOT
from module_layout import PUBLIC_PACKAGES, declaration_providers

OUTPUT = 'docs/api.json'


def _mojo_doc(target, folder):
    out = Path(folder) / (Path(target).stem + '.json')
    subprocess.run(['mojo', 'doc', '-I', 'src', '-o', str(out), str(target)], cwd=ROOT, check=True,
                   capture_output=True, text=True)
    return json.loads(out.read_text())['decl']


def _modules(root):
    """mojo doc module nodes by provider path; private modules are documented one by one."""
    with tempfile.TemporaryDirectory() as folder:
        package = _mojo_doc(root / 'src/fp', folder)
        nodes = {}
        for sub in package['packages']:
            nodes[sub['name']] = sub
            for module in sub['modules']:
                nodes[sub['name'] + '/' + module['name']] = module
        for _, provider, _ in declaration_providers():
            if provider not in nodes:
                nodes[provider] = _mojo_doc(root / f'src/fp/{provider}.mojo', folder)
    return nodes


def _header(lines, start):
    """A declaration header from its first line to the colon that ends it."""
    header = []
    for line in lines[start:]:
        header.append(line.strip())
        if line.rstrip().endswith(':'):
            break
    text = ' '.join(header).removesuffix(':')
    return re.sub(r'\(\s+', '(', re.sub(r'\s+\)', ')', text))


def _source_signatures(path, owner, name):
    """Source headers of `name` (a method of `owner`, or top level), in source order."""
    lines = path.read_text().splitlines()
    current, result = None, []
    for i, line in enumerate(lines):
        found = re.match(r'^(struct|trait) (\w+)', line)
        if found:
            current = found[2]
        elif re.match(r'^(?:def|comptime|@)', line):
            current = None if not line.startswith('@') else current
        method = re.match(r'(    )?def `?(\w+)\b', line)  # a keyword name is in backticks
        if method and method[2] == name and bool(method[1]) == bool(owner) and (not owner or current == owner):
            result.append(_header(lines, i))
    return result


def _type_signature(path, name):
    lines = path.read_text().splitlines()
    start = next(i for i, line in enumerate(lines) if re.match(r'^(?:struct|trait|comptime) ' + re.escape(name) + r'\b', line))
    if lines[start].startswith('comptime '):
        text = []
        balance = 0
        for line in lines[start:]:
            text.append(line.strip())
            balance += sum(line.count(c) for c in '[(') - sum(line.count(c) for c in '])')
            if balance <= 0:
                break
        return ' '.join(text)
    return _header(lines, start)


def balanced_end(text, start):
    """Index just past the bracket that closes the one at `start`."""
    depth = 0
    for i in range(start, len(text)):
        depth += text[i] in '[(' and 1 or 0
        depth -= text[i] in '])' and 1 or 0
        if depth == 0:
            return i + 1
    raise ValueError('unbalanced signature: ' + text)


def split_items(text):
    """Top-level comma-separated items."""
    items, depth, current = [], 0, ''
    for char in text:
        depth += char in '[(' and 1 or 0
        depth -= char in '])' and 1 or 0
        if char == ',' and depth == 0:
            items.append(current.strip())
            current = ''
        else:
            current += char
    return [item for item in items + [current.strip()] if item]


def top_level(text, word):
    """Index of ` word ` outside brackets, or -1."""
    depth = 0
    for i, char in enumerate(text):
        depth += char in '[(' and 1 or 0
        depth -= char in '])' and 1 or 0
        if depth == 0 and text.startswith(word, i):
            return i
    return -1


def _without_default(kind):
    """A parameter or argument type without its `= default`."""
    end = top_level(kind, ' = ')
    return (kind if end < 0 else kind[:end]).strip()


def parse_signature(text):
    """Parameters, arguments, result and error of a declaration header, as written."""
    name = re.match(r'(def|struct|trait|comptime)\s+`?\w+`?', text)
    rest = text[name.end():]
    callable_ = name[1] == 'def'
    parameters, arguments, inferred = [], [], True
    if rest.startswith('['):
        end = balanced_end(rest, 0)
        items = split_items(rest[1:end - 1])
        inferred = '//' in items
        for item in items:
            if item == '//':
                inferred = False
                continue
            name_, _, kind = item.partition(':')
            parameters.append(dict(name=name_.strip().lstrip('*'), variadic=name_.strip().startswith('*'),
                                   type=_without_default(kind), inferred=inferred))
        rest = rest[end:]
    if rest.startswith('(') and callable_:
        end = balanced_end(rest, 0)
        for item in split_items(rest[1:end - 1]):
            if item in ('*', '/') or re.match(r'^(?:(?:var|mut|deinit|out|ref(?:\[[^\]]*\])?)\s+)?self$', item):
                continue
            head, _, kind = item.partition(':')
            words = head.split()
            convention = words[0] if len(words) > 1 else ''
            arg = words[-1]
            arguments.append(dict(name=arg.lstrip('*'), variadic=arg.startswith('*'), convention=convention,
                                  type=_without_default(kind)))
        rest = rest[end:]
    where = top_level(rest, ' where ')
    head = rest if where < 0 else rest[:where]
    arrow = top_level(head, ' -> ')
    result = head[arrow + 4:].strip() if arrow >= 0 else ''
    raises = re.match(r'\s*raises\s*(.*)', head[:arrow] if arrow >= 0 else head)
    return dict(parameters=parameters, arguments=arguments, result=result,
                error=(raises[1].strip() or 'Error') if raises else '')


def _parameters(items):
    return [dict(name=p['name'], type=p.get('type', ''), inferred=p.get('passingKind') == 'inferred',
                 description=p.get('description', '').strip()) for p in items or []]


def _type_parameters(node, path):
    explained = {p['name'].lstrip('*'): p.get('description', '').strip() for p in node.get('parameters', [])}
    parameters = parse_signature(_type_signature(path, node['name']))['parameters']
    for parameter in parameters:
        parameter['description'] = explained.get(parameter['name'], '')
    return parameters


def _overload(node, signature):
    source = parse_signature(signature)
    described = {a['name'].lstrip('*'): a.get('description', '').strip() for a in node.get('args', [])}
    for arg in source['arguments']:
        if arg['name'] not in described:
            raise ValueError(f'overload order differs between mojo doc and the source: {signature}')
        arg['description'] = described[arg['name']]
    explained = {p['name'].lstrip('*'): p.get('description', '').strip() for p in node.get('parameters', [])}
    for parameter in source['parameters']:
        parameter['description'] = explained.get(parameter['name'], '')
    returns = node.get('returns') or {}
    return dict(signature=signature, summary=node.get('summary', '').strip(),
                description=node.get('description', '').strip(),
                parameters=source['parameters'], args=source['arguments'],
                returns=dict(type=source['result'], doc=returns.get('doc', '').strip()) if source['result'] else None,
                raises=bool(source['error']), error=source['error'], raises_doc=node.get('raisesDoc', '').strip())


def _function(node, path, owner=None):
    signatures = _source_signatures(path, owner, node['name'])
    overloads = node.get('overloads', [])
    if len(signatures) != len(overloads):
        raise ValueError(f'{node["name"]}: {len(overloads)} documented overloads, {len(signatures)} in the source')
    return [_overload(o, s) for o, s in zip(overloads, signatures)]


def _find(module, name):
    for kind in ('functions', 'structs', 'traits', 'aliases'):
        for item in module.get(kind, []):
            if item['name'] == name:
                return kind, item
    raise KeyError(name)


def extract(root=ROOT):
    exports = json.loads((root / 'docs/public-exports.json').read_text())['exports']
    nodes = _modules(root)
    packages = {name: dict(summary=nodes[name].get('summary', '').strip(),
                           description=nodes[name].get('description', '').strip())
                for name in PUBLIC_PACKAGES}
    entries = {}
    for full, item in exports.items():
        provider = item['provider']
        path = root / f'src/fp/{provider}.mojo'
        kind, node = _find(nodes[provider], full.split('.', 1)[1])
        entry = dict(provider=provider, summary=node.get('summary', '').strip(),
                     description=node.get('description', '').strip())
        if kind == 'functions':
            entry.update(kind='function', overloads=_function(node, path))
        else:
            entry.update(kind=dict(structs='struct', traits='trait', aliases='alias')[kind], signature=_type_signature(path, node['name']),
                         parameters=_type_parameters(node, path),
                         traits=[t['name'] for t in node.get('parentTraits', [])
                                 if t['name'] not in ('AnyType', 'Deinitable', 'Movable')])
            public = set(item.get('methods', {})) | {'__call__'}
            methods = {}
            for method in node.get('functions', []):
                overloads = method.get('overloads', [])
                if method['name'] in public and (method['name'] != '__call__' or overloads[0].get('summary')):
                    methods[method['name']] = _function(method, path, node['name'])
            entry['methods'] = methods
            entry['fields'] = [dict(name=f['name'], type=f.get('type', ''),
                                    description=(f.get('summary', '') + ' ' + f.get('description', '')).strip())
                               for f in node.get('fields', []) if not f['name'].startswith('_')]
            entry['aliases'] = [dict(name=a['name'], description=(a.get('summary', '') + ' ' + a.get('description', '')).strip())
                                for a in node.get('aliases', []) if not a['name'].startswith('_')]
        entries[full] = entry
    return dict(version=1, packages=packages, entries=entries)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help=f'Fail if {OUTPUT} is stale')
    args = parser.parse_args()
    text = json.dumps(extract(), indent=1, sort_keys=True) + '\n'
    path = ROOT / OUTPUT
    if args.check:
        if not path.is_file() or path.read_text() != text:
            print(f'{OUTPUT} is stale; run python scripts/api_docs.py')
            return 1
        print(f'{OUTPUT} is current')
        return 0
    path.write_text(text)
    print(f'wrote {OUTPUT}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
