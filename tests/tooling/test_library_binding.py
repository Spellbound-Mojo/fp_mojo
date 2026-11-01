"""A selected source or bytecode package stays bound independently of checkout inputs."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]/'scripts'))
from fp_tools.runtime import ROOT
from fp_tools.artifacts import library_inputs, library_binding, audit_library_binding


class LibraryBindingTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(dir=ROOT/'.cache')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def test_source_and_precompiled_packages_retain_the_original_bytes(self):
        for include, filename in [('src', 'fp/__init__.mojo'),
                                  ('.cache/source', 'fp/__init__.mojo'),
                                  ('.cache/bytecode', 'fp.mojoc')]:
            with self.subTest(include=include):
                artifact = self.root/include/filename
                artifact.parent.mkdir(parents=True)
                artifact.write_bytes(b'original library')
                before = library_inputs(include, self.root)
                report = library_binding(include, before, self.root)
                arguments = dict(include=include, expected_inputs=before, root=self.root)
                self.assertEqual(audit_library_binding(report, **arguments), [])
                serialized = json.loads(json.dumps(report).replace(str(self.root), '<PROJECT>'))
                self.assertEqual(audit_library_binding(serialized, **arguments), [])
                artifact.write_bytes(b'replacement library')
                self.assertTrue(audit_library_binding(report, **arguments))
                self.assertTrue(library_binding(include, before, self.root)['library_changes'])
                forged = library_binding(include, library_inputs(include, self.root), self.root)
                self.assertTrue(audit_library_binding(forged, **arguments))

    def test_missing_added_and_malformed_library_bindings_fail(self):
        include = '.cache/package'
        package = self.root/include
        package.mkdir(parents=True)
        artifact = package/'fp.mojoc'; artifact.write_bytes(b'original')
        before = library_inputs(include, self.root)
        report = library_binding(include, before, self.root)
        arguments = dict(include=include, expected_inputs=before, root=self.root)
        for changes in (dict(library_inputs={}), dict(library_inputs=[]),
                        dict(library_changes=['claimed change'])):
            self.assertTrue(audit_library_binding(report | changes, **arguments))
        extra = package/'fp.mojopkg'; extra.write_bytes(b'additional import candidate')
        self.assertTrue(audit_library_binding(report, **arguments))
        extra.unlink()
        self.assertEqual(audit_library_binding(report, **arguments), [])
        artifact.unlink()
        self.assertTrue(audit_library_binding(report, **arguments))
        empty = library_binding(include, {}, self.root)
        self.assertTrue(audit_library_binding(empty, include=include, expected_inputs={}, root=self.root))


if __name__ == '__main__':
    unittest.main()
