"""A focused run must bind ignored package inputs and enforce its hard budget."""
from contextlib import redirect_stderr
from io import StringIO
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[2]/'scripts'))
from measure_compilation import library_inputs, main
from fp_tools.runtime import input_changes


class CompilationMeasurementTests(unittest.TestCase):
    def test_package_and_source_copy_changes_are_visible(self):
        with tempfile.TemporaryDirectory() as name:
            folder = Path(name)
            source = folder/'fp/core.mojo'
            source.parent.mkdir()
            source.write_text('before')
            package = folder/'fp.mojoc'
            package.write_bytes(b'before')
            before = library_inputs(folder)
            source.write_text('after')
            package.write_bytes(b'after')
            self.assertEqual(input_changes(before, library_inputs(folder)),
                             sorted([str(source), str(package)]))
            package.unlink()
            self.assertIn(str(package), input_changes(before, library_inputs(folder)))

    def test_budgets_are_rejected_before_reserving_artifacts(self):
        for flag, value in [('--threads','3'),('--timeout','181'),('--memory-mib','4097')]:
            with self.subTest(flag=flag), patch('sys.argv', ['measure_compilation.py','unused.mojo',flag,value]), \
                    patch('measure_compilation.reserve_output') as reserve, redirect_stderr(StringIO()):
                with self.assertRaises(SystemExit) as failure:
                    main()
                self.assertEqual(failure.exception.code,2)
                reserve.assert_not_called()


if __name__ == '__main__':
    unittest.main()
