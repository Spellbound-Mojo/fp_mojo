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
        self.assertEqual(result['exports'], 134)
        self.assertEqual(result['modules'], 9)
        self.assertEqual(result['examples'], 27)

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


if __name__ == '__main__':
    unittest.main()
