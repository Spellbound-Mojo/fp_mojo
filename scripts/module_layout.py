"""Public packages and declaration providers; paths are relative to src/fp."""
import re

PUBLIC_PACKAGES = ('callables', 'functions', 'adt', 'data', 'iteration', 'control', 'algebra', 'effects', 'matching')

# Public operations declared as compile-time callable values rather than `def`.
# The algebra entries are ordinary functions since the core simplification (CS-2).
CALLABLE_ENTRIES = frozenset()

# Keep declarations at their physical owner; package initializers only re-export.
SOURCE_MODULES = (
    *(( 'callables', 'callables/' + name) for name in ('protocols', 'invoke', 'native')),
    ('functions', 'functions/pipeline'),
    ('functions', 'functions/composition'),
    ('functions', 'functions/flipped'),
    ('functions', 'functions/partial'),
    ('iteration', 'iteration/folds'),
    ('iteration', 'iteration/adapters'),
    ('control', 'control/loops'),
    ('control', 'control/scan'),
    *(( 'algebra', 'algebra/' + name) for name in ('protocols', 'operations', 'instances', '_derived', 'monoids')),
    *(( 'effects', 'effects/' + name) for name in ('protocols', 'reader', 'state', 'writer', 'layers', 'operations')),
    ('data', 'data/_result'),
    ('data', 'data/result'),
    ('data', 'data/control'),
    ('adt', 'adt/data'),
    ('matching', 'matching/clauses'),
    ('matching', 'matching/matcher'),
)

def declaration_providers():
    for package, provider in SOURCE_MODULES:
        yield package, provider, None
    yield 'functions', 'callables/native', ('as_unary',)


def public_providers(root):
    result = {}
    for package, provider, names in declaration_providers():
        for name in re.findall(r'^(?:def|struct|trait|comptime) `?([A-Za-z]\w*)',
                               (root / f'src/fp/{provider}.mojo').read_text(), re.M):
            if names is not None and name not in names:
                continue
            key = package + '.' + name
            if key in result and result[key] != provider:
                raise ValueError('Ambiguous public declaration: ' + key)
            result[key] = provider
    return result


def module_name(path, root):
    parts = path.relative_to(root / 'src/fp').with_suffix('').parts
    if parts[-1] == '__init__' and len(parts) > 1:
        parts = parts[:-1]
    return '.'.join(parts)


def module_imports(path, root):
    """Resolve explicit absolute/relative imports to full package module names."""
    result = set()
    parent = path.parent.relative_to(root / 'src/fp').parts
    for name in re.findall(r'^\s*from ([\w.]+) import', path.read_text(), re.M):
        if name.startswith('fp.'):
            result.add(name[3:])
        elif name.startswith('.'):
            level = len(name) - len(name.lstrip('.'))
            prefix = parent[:len(parent) - level + 1]
            result.add('.'.join((*prefix, name[level:])))
    for name in re.findall(r'^\s*import (fp(?:\.\w+)+)', path.read_text(), re.M):
        result.add(name[3:])
    return sorted(result)
