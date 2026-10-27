"""The import DAG and leaf boundaries are part of the architecture contract."""
import sys
import unittest
from graphlib import TopologicalSorter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from module_layout import module_imports, module_name


def dependencies(root):
    return {module_name(p, root): set(module_imports(p, root))
            for p in (root / 'src/fp').rglob('*.mojo')}


def reachable(graph, start):
    reached, pending = set(), [start]
    while pending:
        module = pending.pop()
        if module in reached:
            continue
        reached.add(module)
        pending.extend(graph.get(module, ()))
    return reached


class ModuleLayerTests(unittest.TestCase):
    def test_all_modules_form_a_dag(self):
        graph = dependencies(ROOT)
        self.assertGreater(len(graph), 50)
        tuple(TopologicalSorter(graph).static_order())

    def test_primitive_contracts_stay_below_derived_algebra(self):
        graph = dependencies(ROOT)
        self.assertIn('algebra._primitive_contracts', graph)
        reached = reachable(graph, 'algebra._primitive_contracts')
        derived = {m for m in graph if m.startswith('algebra.')} - {
            'algebra._primitive_contracts', 'algebra.protocols'}
        self.assertFalse(reached & derived)
        self.assertFalse([m for m in reached if m.split('.')[0] in ('functions', 'effects')])

    def test_leaf_dependencies_do_not_reach_integration_layers(self):
        graph = dependencies(ROOT)
        for leaf in ('data._result', 'data.control', 'data.non_empty_list', 'data.ior', 'adt.data', 'callables._arguments',
                     'functions.composition', 'callables._identity'):
            reached = reachable(graph, leaf)
            with self.subTest(leaf=leaf):
                self.assertFalse([m for m in reached if
                    m.split('.')[0] in ('algebra', 'effects') or
                    m in ('functions.pipeline', 'data', 'data.result')])
                if leaf == 'data._result':
                    self.assertFalse(reached & {'data._attempt', 'data._capture', 'callables._arguments'})
                if leaf in ('data._result', 'callables._identity'):
                    self.assertFalse([m for m in reached if m.split('.')[0] == 'functions'])
                if leaf == 'callables._arguments':
                    self.assertFalse([m for m in reached if m.split('.')[0] == 'data'])


if __name__ == '__main__':
    unittest.main()
