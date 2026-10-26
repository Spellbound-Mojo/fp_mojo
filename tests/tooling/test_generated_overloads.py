"""The plain-function overloads in fp.functions match their generator."""
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[2]/'scripts'))
from fp_tools.runtime import ROOT
import generate_partial as partial
import generate_capture as capture
import generate_context as context
import generate_native_conventions as native
import generate_plain_overloads as generator
import generate_pipeline_syntax as syntax
import generate_combinator_syntax as combinators
import generate_result_syntax as results
import generate_traversal_syntax as traversals
import generate_nary_syntax as nary
import generate_sequencing_syntax as sequencing


class GeneratedOverloadTests(unittest.TestCase):
    def test_selected_context_matches_the_generator(self):
        self.assertEqual(context.OUTPUT.read_text(), context.source())

    def test_partial_arities_match_the_generator(self):
        self.assertEqual(partial.OUTPUT.read_text(), partial.source())

    def test_capture_signatures_match_the_generator(self):
        self.assertEqual(capture.OUTPUT.read_text(), capture.source())
        self.assertEqual(capture.ARGUMENT_OUTPUT.read_text(), capture.arguments_source())

    def test_native_invocation_matches_the_generator(self):
        self.assertEqual(native.OUTPUT.read_text(), native.source())

    def test_sources_match_the_generator(self):
        folder = ROOT/'src/fp/functions'
        for name, render in (('pipeline.mojo', generator.pipeline_source),
                             ('composition.mojo', lambda path: generator.spliced(path, generator.composition_overloads()))):
            with self.subTest(module=name):
                path = folder/name
                self.assertEqual(path.read_text(), render(path),
                                 'run python scripts/generate_plain_overloads.py')

        native = ROOT / 'src/fp/callables/_nary.mojo'
        self.assertEqual(native.read_text(), nary.native())
        metadata = ROOT / 'src/fp/algebra/_nary.mojo'
        self.assertEqual(metadata.read_text(), generator.spliced(
            metadata, nary.types(), nary.START, nary.END, nary.HEADER))

    def test_result_methods_match_the_generator(self):
        path = ROOT / 'src/fp/data/_result.mojo'
        self.assertEqual(path.read_text(), generator.spliced(
            path, results.methods(), results.START, results.END, results.HEADER))

    def test_new_carrier_uses_existing_operation_templates(self):
        # Adding a native shape must not require per-operation handwritten Mojo.
        carrier = syntax.Carrier('Example', 'Example[{element}, N]',
                                 'ExampleFamily[N]', ('N: Int',))
        mapped = syntax.map_methods(carrier)
        filtered = syntax.filter_methods(carrier, 'filter_not', 'Retain rejected')
        self.assertIn('Piped[Example[U, N]]', mapped)
        self.assertIn('_family_map[ExampleFamily[N], X=E]', mapped)
        self.assertIn('_family_filter_not[ExampleFamily[N], E=E]', filtered)
        self.assertIn('where R == Bool and Self.Value == Example[T, N]', filtered)
        self.assertIn('C.Failure', filtered)
        self.assertIn('_Fill[T, U]', syntax.transform_methods(carrier))
        self.assertIn('ExampleFamily[N].filter_map', syntax.algebra_methods(carrier))
        self.assertNotIn('def flat_map', syntax.algebra_methods(carrier))

    def test_terminal_sources_match_the_generator(self):
        for name, mode, indent in (('reductions', 'free', ''), ('chaining', 'iter', '    ')):
            path = ROOT / f'src/fp/iteration/{name}.mojo'
            expected = generator.spliced(path, combinators.terminal_methods(mode),
                                         indent + combinators.START, indent + combinators.END,
                                         indent + combinators.HEADER)
            self.assertEqual(path.read_text(), expected)

    def test_traversal_sources_match_the_generator(self):
        for name, mode, indent in (('derived', 'free', ''), ('chaining', 'iter', '    ')):
            path = ROOT / f'src/fp/iteration/{name}.mojo'
            expected = generator.spliced(path, traversals.methods(mode),
                                         indent + traversals.START, indent + traversals.END,
                                         indent + traversals.HEADER)
            self.assertEqual(path.read_text(), expected)

    def test_filter_capability_excludes_fixed_or_nonempty_carriers(self):
        names = {c.name for c in syntax.CARRIERS if 'filter' in c.capabilities}
        self.assertEqual(names, {'List', 'Deque', 'LinkedList', 'Dict', 'StringDict', 'Optional'})

    def test_sequencing_sources_match_the_generator(self):
        path = ROOT / 'src/fp/iteration/chaining.mojo'
        self.assertEqual(path.read_text(), generator.spliced(
            path, sequencing.methods(iteration=True),
            sequencing.START, sequencing.END, sequencing.HEADER))

    def test_later_stages_name_their_own_input(self):
        # A mismatched call must still select the overload and reach the stage check.
        self.assertEqual(generator.stage(1, 2)[0], 'def(var P2) raises E2 thin -> A3')
        self.assertIn('P1: Movable & Deinitable', generator.decls(2, 1))
        self.assertEqual(generator.stage(1, 0)[0], 'def(var A0) raises E0 thin -> A1')


if __name__ == '__main__':
    unittest.main()
