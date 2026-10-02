"""The plain-function overloads in fp.functions match their generator."""
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[2]/'scripts'))
from fp_tools.runtime import ROOT
import generate_plain_overloads as generator


class GeneratedOverloadTests(unittest.TestCase):
    def test_sources_match_the_generator(self):
        folder = ROOT/'src/fp/functions'
        for name, text in (('pipeline.mojo', generator.pipe_overloads()),
                           ('composition.mojo', generator.composition_overloads())):
            with self.subTest(module=name):
                path = folder/name
                self.assertEqual(path.read_text(), generator.spliced(path, text),
                                 'run python scripts/generate_plain_overloads.py')

    def test_later_stages_name_their_own_input(self):
        # A mismatched call must still select the overload and reach the stage check.
        self.assertEqual(generator.stage(1, 2)[0], 'def(var P2) raises E2 thin -> A3')
        self.assertIn('P1: Movable & Deinitable', generator.decls(2, 1))
        self.assertEqual(generator.stage(1, 0)[0], 'def(var A0) raises E0 thin -> A1')


if __name__ == '__main__':
    unittest.main()
