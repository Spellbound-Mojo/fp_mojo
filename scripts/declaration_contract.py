"""Reviewed public declarations shared by the export and documentation contracts."""
import hashlib
import re
from fp_tools.runtime import ROOT

from module_layout import (PUBLIC_PACKAGES as MODULES,
                           CALLABLE_ENTRIES, declaration_providers)

def declaration_sources(root):
    for package, provider, names in declaration_providers():
        yield package, root / f'src/fp/{provider}.mojo', names


def declaration_sites(root=ROOT):
    """One authoritative parser for reviewed signatures and their source locations."""
    for module, path, names in declaration_sources(root):
        lines = path.read_text().splitlines()
        owner = None
        owner_kind = None
        for i, line in enumerate(lines):
            entry = re.match(r'^comptime (\w+)\[', line)
            if entry and module + '.' + entry[1] in CALLABLE_ENTRIES:
                signature = line.strip()
                yield dict(operation=module + '.' + entry[1], signature=signature,
                           sha256=hashlib.sha256(signature.encode()).hexdigest(),
                           path=str(path.relative_to(root)), line=i + 1,
                           kind='implementation')
                owner = None
                continue
            found = re.match(r'^(struct|trait) (\w+)', line)
            if found:
                owner_kind, owner = found.groups()
            elif re.match(r'^(?:def|comptime)\b', line):
                owner = None
            # A wrapped struct header can end with an unindented `):`.
            # That continuation does not end the owner scope.
            # A name that is a keyword, such as `match`, is declared in backticks.
            match = re.match(r'(    )?def `?(\w+)`?', line)
            if not match or (match[2].startswith('_') and not (module in ('result', 'data') and owner == 'Result' and match[2] == '__init__')):
                continue
            if match[1] and (not owner or owner.startswith('_')):
                continue
            if names is not None and (owner if match[1] else match[2]) not in names:
                continue
            name = '.'.join(x for x in (module, owner if match[1] else None, match[2]) if x)
            # Declarations end at the colon at the end of a physical line. Types
            # can contain colons internally; preserve the full normalized header.
            header = []
            for tail in lines[i:]:
                header.append(tail.strip())
                if tail.rstrip().endswith(':'): break
            signature = ' '.join(header)
            yield dict(operation=name, signature=signature,
                       sha256=hashlib.sha256(signature.encode()).hexdigest(),
                       path=str(path.relative_to(root)), line=i + 1,
                       kind='protocol' if match[1] and owner_kind == 'trait' else 'implementation')


def declarations(root=ROOT):
    result = {}
    for site in declaration_sites(root):
        result.setdefault(site['operation'], []).append({key: site[key] for key in ('signature', 'sha256')})
    return result


def public_types(root=ROOT):
    result = {}
    for module, path, names in declaration_sources(root):
        for line in path.read_text().splitlines():
            match = re.match(r'^(?:struct|trait|comptime) ([A-Za-z]\w*)', line)
            if match and (names is None or match[1] in names):
                if module + '.' + match[1] in CALLABLE_ENTRIES:
                    continue
                result.setdefault(module+'.'+match[1], []).append(line.strip())
    return result
