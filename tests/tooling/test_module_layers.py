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


class ModuleLayerTests(unittest.TestCase):
    def test_all_modules_form_a_dag(self):
        graph = dependencies(ROOT)
        self.assertGreater(len(graph), 50)
        tuple(TopologicalSorter(graph).static_order())

    def test_leaf_dependencies_do_not_reach_integration_layers(self):
        graph = dependencies(ROOT)
        for leaf in ('data._result', 'data.control', 'data.non_empty_list', 'data.ior', 'adt.data',
                     'functions.composition'):
            reached, pending = set(), [leaf]
            while pending:
                module = pending.pop()
                if module in reached:
                    continue
                reached.add(module)
                pending.extend(graph.get(module, ()))
            with self.subTest(leaf=leaf):
                self.assertFalse([m for m in reached if
                    m.split('.')[0] in ('algebra', 'effects') or
                    m in ('functions.pipeline', 'data', 'data.result')])


if __name__ == '__main__':
    unittest.main()
