"""Nested namespaces preserve function, method, provider, and doc ownership."""
import copy
import json
import sys
import tempfile
import unittest
from contextlib import ExitStack
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
import api_docs
import api_reference
import declaration_contract
import docs_contract
import export_contract
import module_layout

PACKAGES = ('effects', 'effects.async_runtime', 'effects.async_runtime.protocols')


class NestedNamespaceTests(unittest.TestCase):
    def test_longest_namespace_wins(self):
        self.assertEqual(module_layout.split_public_name('effects.async_runtime.Driver.poll', PACKAGES),
                         ('effects.async_runtime', 'Driver.poll'))
        self.assertEqual(module_layout.split_public_name('effects.async_runtime.protocols.Machine.poll', PACKAGES),
                         ('effects.async_runtime.protocols', 'Machine.poll'))
        with self.assertRaises(ValueError):
            module_layout.split_public_name('effectful.Driver', PACKAGES)

    def test_export_methods_and_nested_module_audit(self):
        providers = [('effects.async_runtime', 'effects/async_runtime/_host', None),
                     ('effects.async_runtime.protocols', 'effects/async_runtime/protocols', None)]
        with tempfile.TemporaryDirectory() as folder, ExitStack() as stack:
            root = Path(folder)
            source = root / 'src/fp/effects/async_runtime'
            source.mkdir(parents=True)
            (source / '_host.mojo').write_text('struct Driver(Movable):\n    def poll(self):\n        pass\ndef sleep():\n    pass\n')
            (source / 'protocols.mojo').write_text('trait Machine:\n    def poll(mut self):\n        ...\n')
            for module in (module_layout, declaration_contract):
                stack.enter_context(patch.object(module, 'declaration_providers', lambda: iter(providers)))
            stack.enter_context(patch.object(export_contract, 'MODULES', PACKAGES))
            inventory = export_contract.export_inventory(root)
            entries = inventory['exports']
            self.assertEqual(entries['effects.async_runtime.sleep']['kind'], 'function')
            self.assertEqual(set(entries['effects.async_runtime.Driver']['methods']), {'poll'})
            self.assertEqual(set(entries['effects.async_runtime.protocols.Machine']['methods']), {'poll'})
            (root / 'docs').mkdir()
            (root / 'docs/public-exports.json').write_text(json.dumps(inventory))
            self.assertEqual(export_contract.audit_exports(root)['modules'], 3)
            (source / 'unreviewed').mkdir()
            with self.assertRaisesRegex(ValueError, 'Unreviewed public module'):
                export_contract.audit_exports(root)

    def test_mojo_doc_walks_nested_packages_and_modules(self):
        tree = dict(packages=[dict(name='effects', packages=[dict(name='async_runtime',
                    packages=[], modules=[dict(name='protocols')])], modules=[])])
        with patch.object(api_docs, '_mojo_doc', return_value=tree), \
                patch.object(api_docs, 'declaration_providers', return_value=[]):
            nodes = api_docs._modules(ROOT)
        self.assertIn('effects/async_runtime', nodes)
        self.assertIn('effects/async_runtime/protocols', nodes)

    def test_nested_reference_and_missing_doc_audit(self):
        source = docs_contract.data('api.json')
        entry = copy.deepcopy(source['entries']['effects.IOContext'])
        entry['provider'] = 'effects/async_runtime/_host'
        api = dict(packages={p: dict(summary=p, description='') for p in PACKAGES}, entries={
            'effects.Driver': copy.deepcopy(entry),
            'effects.async_runtime.Driver': entry,
        })
        owners = api_reference.documentation_owners(api)
        self.assertEqual(owners['effects.Driver'], 'effects.async_runtime')
        rendered = api_reference.package_markdown('effects.async_runtime', api, lambda owner, name: owner + '#' + name)
        self.assertIn('{ #Driver .api-name }', rendered)
        entry['summary'] = ''
        self.assertIn('Driver: summary', docs_contract.api_problems('effects.async_runtime', api))


if __name__ == '__main__':
    unittest.main()
