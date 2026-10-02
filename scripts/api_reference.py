"""Render a package's API reference page from docs/api.json; no MkDocs dependency.

Each public name gets one entry: its signature, a short description, any
limitations, then Parameters (compile-time), Arguments, Returns and Raises, and
for types their fields, associated aliases and methods. Every documented
overload gets its own block; the others are listed in a collapsed block.
"""
import html
import re
import textwrap

from api_docs import balanced_end, split_items

KINDS = (('function', 'Functions'), ('struct', 'Structs'), ('trait', 'Traits'), ('alias', 'Aliases'))
_BOUND = re.compile(r'\s*:\s*(?:Movable & Deinitable|Deinitable & Movable)(?=\s*[,\]])')
_PRIVATE = re.compile(r'(?<![\w.])_[A-Za-z]\w*')
WIDTH = 80
SECTIONS = ('Limitations',)


def plain(text):
    """Source text as a reader sees it inside a type: `Self.T` is `T`."""
    return text.replace('Self.', '')


def type_name(text):
    return plain('Movable & Deinitable' if text == 'Deinitable & Movable' else text)


def public_type(text):
    """A type as documentation shows it: private helpers are hidden, keeping a public outer name."""
    text = type_name(text)
    if not _PRIVATE.search(text):
        return text
    head = text.split('[', 1)[0]
    return head + '[...]' if '[' in text and not _PRIVATE.search(head) else ''


def _wrap(open_, items, close):
    """One item per line."""
    return open_ + '\n' + ''.join(f'    {item},\n' for item in items) + close


def _fill(open_, items, close):
    """Items filled to the line width."""
    return open_ + '\n' + textwrap.fill(', '.join(items) + ',', WIDTH, initial_indent='    ',
                                        subsequent_indent='    ', break_on_hyphens=False) + '\n' + close


def display_signature(text):
    """The source signature without the ubiquitous `Movable & Deinitable` bound, wrapped when long."""
    text = plain(_BOUND.sub('', text))
    if len(text) <= WIDTH:
        return text
    head = re.match(r'(?:def|struct|trait)\s+\w+', text)
    if not head:
        return text
    name, rest = text[:head.end()], text[head.end():]
    parameters = ''
    if rest.startswith('['):
        end = balanced_end(rest, 0)
        parameters, rest = rest[:end], rest[end:]
    if not rest.startswith('('):
        return text if len(name + parameters) <= WIDTH else _fill(name + '[', split_items(parameters[1:-1]), ']') + rest
    end = balanced_end(rest, 0)
    arguments, tail = split_items(rest[1:end - 1]), rest[end:]
    if len(name + parameters) > WIDTH - 1:
        name, parameters = _fill(name + '[', split_items(parameters[1:-1]), ']'), ''
    return _wrap(name + parameters + '(', arguments, ')') + tail if arguments else name + parameters + '()' + tail


def split_description(text):
    """The free text and the indented `Limitations:` block of a docstring description."""
    body, limits, current = [], [], None
    for line in text.splitlines():
        if line.strip() in (s + ':' for s in SECTIONS):
            current = limits
            continue
        if current is limits and line and not line.startswith((' ', '\t')):
            current = None
        (limits if current is limits else body).append(line)
    return '\n'.join(body).strip(), textwrap.dedent('\n'.join(limits)).strip()


def documented(overload):
    return bool(overload['description'] or overload['raises_doc']
                or (overload['returns'] or {}).get('doc')
                or any(p['description'] for p in overload['parameters'])
                or any(a['description'] for a in overload['args']))


def primaries(overloads):
    """The overloads that carry full documentation, or the first."""
    chosen = [o for o in overloads if documented(o)]
    return chosen or overloads[:1]


def _signature(text):
    return ['<div class="api-signature" markdown="1">', '', '```mojo', text, '```', '', '</div>', '']


def _prose(summary, description):
    """The summary line as the lead paragraph, then the rest of the description."""
    return [summary, ''] + ([description, ''] if description else [])


def _list(title, items, describe):
    if not items:
        return []
    return [f'**{title}**', ''] + [describe(item) for item in items] + ['']


def _item(name, kind, description, note=''):
    """`- name (type, note): description`, leaving out what is empty."""
    label = ', '.join(part for part in (kind and f'`{kind}`', note) if part)
    return f'- **`{name}`**' + (f' ({label})' if label else '') + (f': {description}' if description else '')


def _parameter(p):
    return _item(('*' if p['variadic'] else '') + p['name'], public_type(p['type']), p['description'],
                 'inferred' if p['inferred'] else '')


def _argument(a):
    convention = a['convention'] if a['convention'] not in ('read', 'imm') else ''
    return _item(('*' if a['variadic'] else '') + a['name'], (convention + ' ' if convention else '') + type_name(a['type']),
                 a['description'])


def _typed(kind, description):
    """`Type`: description, without a type that names private helpers."""
    kind = public_type(kind)
    return ': '.join(part for part in (kind and f'`{kind}`', description) if part)


def overload_markdown(overload):
    """Signature, description and sections of one documented overload."""
    description, limits = split_description(overload['description'])
    out = _signature(display_signature(overload['signature'])) + _prose(overload['summary'], description)
    if limits:
        out += ['!!! note "Limitations"', '', textwrap.indent(limits, '    '), '']
    out += _list('Parameters', overload['parameters'], _parameter)
    out += _list('Arguments', overload['args'], _argument)
    returns = overload['returns']
    if returns and returns['type'] not in ('', 'None'):
        out += ['**Returns**', '', _typed(returns['type'], returns['doc']), '']
    if overload['raises']:
        out += ['**Raises**', '', _typed(overload['error'], overload['raises_doc']), '']
    return out


def heading(level, title, anchor):
    return [f'{"#" * level} {title.replace("_", chr(92) + "_")} {{ #{anchor} .api-name }}', '']


def callable_markdown(name, overloads, anchor, level, source=''):
    """One function or method: each documented overload, then the rest collapsed."""
    main = primaries(overloads)
    out = heading(level, name, anchor) + ([source, ''] if source else [])
    for overload in main:
        out += overload_markdown(overload)
    rest = [o for o in overloads if o not in main]
    if rest:
        body = '\n'.join(f'<p>{html.escape(o["summary"])}</p><pre><code>{html.escape(display_signature(o["signature"]))}</code></pre>'
                         for o in rest)
        out += [f'<details class="api-overloads"><summary>{len(rest)} more overload{"s" if len(rest) > 1 else ""}</summary>',
                body, '</details>', '']
    return out


def type_markdown(name, entry, anchor, source=''):
    description, limits = split_description(entry['description'])
    out = heading(3, name, anchor) + ([source, ''] if source else []) + _signature(display_signature(entry['signature']))
    out += _prose(entry['summary'], description)
    if limits:
        out += ['!!! note "Limitations"', '', textwrap.indent(limits, '    '), '']
    out += _list('Parameters', entry['parameters'], _parameter)
    if entry.get('traits'):
        out += ['**Implements**', '', ', '.join(f'`{t}`' for t in entry['traits']), '']
    out += _list('Fields', entry.get('fields'), lambda f: _item(f['name'], public_type(f['type']), f['description']))
    out += _list('Associated aliases' if entry['kind'] == 'trait' else 'Aliases', entry.get('aliases'),
                 lambda a: _item(a['name'], '', a['description']))
    for method, overloads in entry.get('methods', {}).items():
        out += callable_markdown(f'{name}.{method}', overloads, f'{name}.{method}', 4)
    return out


def package_markdown(package, api, page_of, source_of=None):
    """A package page: overview, a summary table, then one entry per public name.

    `page_of(owner_package, name)` returns the link to a re-exported name's entry,
    and `source_of(provider)`, when given, the link to a provider's source file.
    """
    info = api['packages'][package]
    entries = {full.split('.', 1)[1]: entry for full, entry in api['entries'].items()
               if full.split('.', 1)[0] == package}
    out = [info['summary'], '', info['description'], '', '## Summary', '', '| Name | Kind | Summary |', '|---|---|---|']
    own = {name: e for name, e in entries.items() if e['provider'].split('/')[0] == package}
    for kind, _ in KINDS:
        for name, entry in own.items():
            if entry['kind'] == kind:
                summary = entry['summary'] or primaries(entry.get('overloads', [{}]))[0].get('summary', '')
                out.append(f'| [`{name}`](#{name}) | {kind} | {summary} |')
    for name, entry in entries.items():
        if name not in own:
            owner = entry['provider'].split('/')[0]
            out.append(f'| [`{name}`]({page_of(owner, name)}) | re-export | Re-exported from `fp.{owner}`. |')
    out.append('')
    for kind, title in KINDS:
        names = [name for name, entry in own.items() if entry['kind'] == kind]
        if not names:
            continue
        out += [f'## {title}', '']
        for name in names:
            entry = own[name]
            source = f'Source: [`fp/{entry["provider"]}.mojo`]({source_of(entry["provider"])})' if source_of else ''
            out += (callable_markdown(name, entry['overloads'], name, 3, source) if kind == 'function'
                    else type_markdown(name, entry, name, source))
    return '\n'.join(out)
