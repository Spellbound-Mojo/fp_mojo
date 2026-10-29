"""Reviewed public names and their providers, excluding incidental Mojo imports."""
import json
from declaration_contract import MODULES, declarations, public_types
from fp_tools.runtime import ROOT, sha
from module_layout import public_providers, split_public_name


def export_inventory(root=ROOT):
    operations = declarations(root)
    types = public_types(root)
    providers = public_providers(root)
    exports = {}
    for name, headers in types.items():
        exports[name] = dict(kind='type or alias', declarations=headers)
    for name, overloads in operations.items():
        package, relative = split_public_name(name, MODULES)
        if '.' not in relative:
            exports[name] = dict(kind='function', overloads=overloads)
        else:
            owner, method = relative.split('.', 1)
            exports[package + '.' + owner].setdefault('methods', {})[method] = overloads
    for name, value in exports.items():
        value['provider'] = providers[name]
    return dict(version=1, modules=list(MODULES), exports=exports)


def audit_exports(root=ROOT):
    path = root / 'docs/public-exports.json'
    expected = json.loads(path.read_text())
    actual = export_inventory(root)
    if expected != actual:
        raise ValueError('Unreviewed public export/provider/signature change')
    source = root / 'src/fp'
    public_packages = {'.'.join(p.relative_to(source).parts) for p in source.rglob('*')
                       if p.is_dir() and not any(part.startswith('_') for part in p.relative_to(source).parts)}
    if any(not p.stem.startswith('_') for p in (root / 'src/fp').glob('*.mojo')):
        raise ValueError('Unexpected flat public module')
    reviewed_packages = {name for name in MODULES if (source / name.replace('.', '/')).is_dir()}
    if public_packages != reviewed_packages or any(
        not (source / name.replace('.', '/')).is_dir() and
        not (source / (name.replace('.', '/') + '.mojo')).is_file() for name in MODULES
    ):
        raise ValueError('Unreviewed public module')
    return dict(exports=len(actual['exports']), modules=len(MODULES), sha256=sha(path))
