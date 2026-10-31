"""Public packages and declaration providers; paths are relative to src/fp."""
import re

PUBLIC_PACKAGES = ('callables', 'functions', 'adt', 'data', 'iteration', 'control', 'algebra', 'algebra.contracts', 'effects', 'matching', 'effects.async_runtime', 'effects.async_runtime.protocols')


def split_public_name(name, packages=PUBLIC_PACKAGES):
    """Separate a reviewed namespace from its declaration or type method."""
    matches = [p for p in packages if name.startswith(p + '.')]
    if not matches:
        raise ValueError('Unknown public namespace: ' + name)
    package = max(matches, key=len)
    return package, name[len(package) + 1:]

# Public operations declared as compile-time callable values rather than `def`.
# The algebra entries are ordinary functions since the core simplification (CS-2).
CALLABLE_ENTRIES = frozenset()

# Keep declarations at their physical owner; package initializers only re-export.
SOURCE_MODULES = (
    *(( 'callables', 'callables/' + name) for name in ('protocols', 'invoke', 'native', '_receiver')),
    ('functions', 'functions/pipeline'),
    ('functions', 'functions/context'),
    ('functions', 'functions/_recovery'),
    ('functions', 'functions/_outcomes'),
    ('functions', 'functions/composition'),
    ('functions', 'callables/_identity'),
    ('functions', 'functions/kleisli'),
    ('functions', 'functions/flipped'),
    ('functions', 'functions/tupled'),
    ('functions', 'functions/untupled'),
    ('functions', 'callables/products'),
    ('functions', 'functions/products'),
    ('functions', 'functions/partial'),
    ('iteration', 'iteration/folds'),
    ('iteration', 'iteration/non_empty'),
    ('iteration', 'iteration/adapters'),
    ('iteration', 'iteration/chaining'),
    ('iteration', 'iteration/derived'),
    ('iteration', 'iteration/reductions'),
    ('iteration', 'iteration/effectful'),
    ('iteration', 'iteration/prefixes'),
    ('iteration', 'iteration/indexed'),
    ('iteration', 'iteration/terminals'),
    ('iteration', 'iteration/branching'),
    ('iteration', 'iteration/alignment'),
    ('iteration', 'iteration/scans'),
    ('control', 'control/loops'),
    ('control', 'control/scan'),
    *(( 'algebra', 'algebra/' + name) for name in ('protocols', 'operations', 'filtering', 'conditional', 'errors', 'error_mapping', 'instances', 'collections', '_primitive_contracts', '_contracts', 'sequencing', '_outcomes', '_derived', '_traversal', 'monoids', 'validation', 'accumulate', 'non_empty', 'ior', 'absence', 'looping')),
    *(( 'effects', 'effects/' + name) for name in ('protocols', 'reader', 'state', 'writer', 'layers', 'operations', 'capabilities', 'projections', 'outcomes', 'resources', '_io_core', '_native_resource_io', 'scoped', 'finalization', 'effectful_resources', 'fibers', 'coordination')),
    ('data', 'data/_result'),
    ('data', 'data/_attempt'),
    ('data', 'data/_capture'),
    ('data', 'data/result'),
    ('data', 'data/non_empty_list'),
    ('data', 'data/control'),
    ('data', 'data/ior'),
    ('adt', 'adt/data'),
    ('matching', 'matching/clauses'),
    ('matching', 'matching/matcher'),
)

ASYNC_PROVIDERS = (
    ('effects.async_runtime', 'effects/_async/engine', ('IO', 'Async', 'Fiber', 'RaceWinner', 'RacePairResult', 'Ref', 'Deferred')),
    ('effects.async_runtime', 'effects/_async/fibers', ('FiberInfo', 'FiberStatus')),
    ('effects.async_runtime', 'effects/_async/supervisor', ('Supervisor',)),
    ('effects.async_runtime', 'effects/_async/io_resource', ('Resource',)),
    ('effects.async_runtime', 'effects/_async/coordination', ('Queue', 'Semaphore')),
    ('effects.async_runtime', 'effects/_async/host', ('Clock', 'Driver', 'TestControl', 'run')),
    ('effects.async_runtime', 'effects/_async/kernel', ('Progress', 'IORuntimeConfig')),
    ('effects.async_runtime', '_internal/time', ('Duration', 'Instant')),
    ('effects.async_runtime', 'effects/_async/racing', ('RaceResult',)),
    ('effects.async_runtime', 'effects/_async/finalization', ('Poll',)),
    ('effects.async_runtime', 'effects/_async/callbacks', ('Completion',)),
    ('effects.async_runtime.protocols', 'effects/_async/kernel', ('Machine',)),
    ('effects.async_runtime.protocols', 'effects/_async/scopes', ('ScopedMachine', 'CleanupMachine')),
    ('effects.async_runtime.protocols', 'effects/_async/kernel', ('Step', 'Wait')),
    ('effects.async_runtime.protocols', '_internal/waking', ('Signal',)),
    ('effects.async_runtime.protocols', 'effects/async_runtime/protocols', ('Context',)),
)

def _contract(name):
    return name.endswith('Contract')


def _not_contract(name):
    return not name.endswith('Contract')


def admits(names, name):
    """Whether a provider's name filter (None, a collection or a predicate) admits a name."""
    return names is None or (names(name) if callable(names) else name in names)


def declaration_providers():
    yield from ASYNC_PROVIDERS
    for package, provider in SOURCE_MODULES:
        # Operation contracts are published under fp.algebra.contracts,
        # at their physical owners; the algebra package keeps everything else.
        if package == 'algebra':
            yield 'algebra', provider, _not_contract
            yield 'algebra.contracts', provider, _contract
        else:
            yield package, provider, None
    yield 'functions', 'callables/native', ('as_unary', 'as_binary')


def public_providers(root):
    result = {}
    for package, provider, names in declaration_providers():
        for name in re.findall(r'^(?:def|struct|trait|comptime) `?([A-Za-z]\w*)',
                               (root / f'src/fp/{provider}.mojo').read_text(), re.M):
            if not admits(names, name):
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
