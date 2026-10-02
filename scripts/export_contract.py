"""Reviewed public names and their providers, excluding incidental Mojo imports."""
import json
from declaration_contract import MODULES, declarations, public_types
from fp_tools.runtime import ROOT, sha
from module_layout import public_providers


def export_inventory(root=ROOT):
    operations = declarations(root)
    types = public_types(root)
    providers = public_providers(root)
    exports = {}
    for name, headers in types.items():
        exports[name] = dict(kind='type or alias', declarations=headers)
    for name, overloads in operations.items():
        parts = name.split('.')
        if len(parts) == 2:
            exports[name] = dict(kind='function', overloads=overloads)
        else:
            exports['.'.join(parts[:2])].setdefault('methods', {})[parts[2]] = overloads
    for name, value in exports.items():
        value['provider'] = providers[name]
    return dict(version=1, modules=list(MODULES), exports=exports)


def audit_exports(root=ROOT):
    path = root / 'docs/public-exports.json'
    expected = json.loads(path.read_text())
    actual = export_inventory(root)
    if expected != actual:
        raise ValueError('Unreviewed public export/provider/signature change')
    public_modules = {p.name for p in (root / 'src/fp').iterdir()
                      if p.is_dir() and not p.name.startswith('_')}
    if any(not p.stem.startswith('_') for p in (root / 'src/fp').glob('*.mojo')):
        raise ValueError('Unexpected flat public module')
    if public_modules != set(MODULES):
        raise ValueError('Unreviewed public module')
    return dict(exports=len(actual['exports']), modules=len(MODULES), sha256=sha(path))
