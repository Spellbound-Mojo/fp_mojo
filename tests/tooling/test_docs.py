"""Prevent silent omissions and accidental expansion in published documentation."""
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
import docs_contract


class DocumentationContractTests(unittest.TestCase):
    def test_complete_reviewed_inventory(self):
        result = docs_contract.audit_docs()
        self.assertEqual(result['exports'], 319)
        self.assertEqual(result['modules'], 10)
        self.assertEqual(result['examples'], 82)

    def test_relocated_identity_keeps_its_public_reference(self):
        rendered = docs_contract.package_page('functions', 'reference/functions.md')
        self.assertTrue('{ #Identity .api-name }' in rendered, 'Missing Identity reference entry')
        self.assertTrue('downloads/src/fp/callables/_identity.mojo' in rendered, 'Missing relocated source link')
        self.assertFalse('callables.md#Identity' in rendered, 'Identity was linked to its private implementation package')
        self.assertTrue('callables.md#as_unary' in rendered, 'Missing existing as_unary re-export link')
        self.assertFalse('{ #as_unary .api-name }' in rendered, 'Duplicate as_unary reference entry')

    def test_relocated_identity_docstring_is_still_audited(self):
        api = docs_contract.data('api.json')
        api['entries']['functions.Identity']['summary'] = ''
        self.assertIn('Identity: summary', docs_contract.api_problems('functions', api))

    def test_literal_directive_in_code_is_not_expanded(self):
        text = '# Authoring\n\n```text\n<!-- api: not_a_module -->\n```\n'
        self.assertEqual(docs_contract.render_markdown(text, 'authoring.md'), text)

    def test_undocumented_entry_rejected(self):
        original = docs_contract.data
        def changed(name):
            value = original(name)
            if name == 'api.json':
                value['entries']['functions.identity']['overloads'][0]['args'][0]['description'] = ''
            return value
        with patch.object(docs_contract, 'data', changed):
            with self.assertRaisesRegex(AssertionError, 'Undocumented API in fp.functions'):
                docs_contract.audit_docs()

    def test_unlisted_example_rejected(self):
        original = docs_contract.data
        def changed(name):
            value = original(name)
            if name == 'examples.json':
                value['examples'].pop('docs/examples/quickstart.mojo')
            return value
        with patch.object(docs_contract, 'data', changed):
            with self.assertRaisesRegex(AssertionError, 'executable example'):
                docs_contract.audit_docs()

    def test_missing_pipeline_contract_rejected(self):
        original = docs_contract.data
        def changed(name):
            value = original(name)
            if name == 'compatibility.json':
                value['pipeline'][0]['methods'].pop()
            return value
        with patch.object(docs_contract, 'data', changed):
            with self.assertRaisesRegex(AssertionError, 'Unclassified Pipeline method'):
                docs_contract.audit_docs()

    def test_missing_migration_assignment_rejected(self):
        # Model an operation still missing from Pipeline even when the current
        # catalog has completed migration. A pending group must account for it.
        from compatibility_contract import audit_compatibility
        catalog = docs_contract.data('compatibility.json')
        exports = docs_contract.data('public-exports.json')
        name = next(name for name in catalog['legacy_methods']
                    if name in exports['exports']['functions.Pipeline']['methods'])
        exports['exports']['functions.Pipeline']['methods'].pop(name)
        for group in catalog['pipeline']:
            if name in group['methods']:
                group['methods'].remove(name)
        with self.assertRaisesRegex(AssertionError, 'migration inventory'):
            audit_compatibility(catalog, exports)


if __name__ == '__main__':
    unittest.main()
