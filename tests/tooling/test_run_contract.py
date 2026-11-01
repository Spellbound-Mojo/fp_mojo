"""Compile cases are immutable and run outputs cannot be reused."""
from dataclasses import FrozenInstanceError
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[2]/'scripts'))
from fp_tools.cases import CompileCase
from fp_tools.runtime import ROOT, reserve_output


class RunContractTests(unittest.TestCase):
    def test_immutable_specs_and_rejection_contract(self):
        case = CompileCase('source.mojo', 'a'*64, 0)
        with self.assertRaises(FrozenInstanceError):
            case.optimization = 3
        for change in ({'optimization':False}, {'optimization':1}, {'reject':()},
                       {'reject':['error']}, {'reject':('error',),'stdout_sha256':'a'*64},
                       {'source_sha256':'wrong'}, {'werror':1}, {'compiler_threads':0},
                       {'memory_limit_bytes':True}, {'execution_memory_limit_bytes':0},
                       {'execution_memory_limit_bytes':True}, {'measured':1},
                       {'defines':['A=1']}, {'defines':('A',)}, {'defines':('1A=1',)}, {'defines':('A=',)}):
            values = dict(source='source.mojo', source_sha256='a'*64, optimization=0) | change
            with self.assertRaises(ValueError):
                CompileCase(**values)

    def test_defines_reach_the_compiler(self):
        case = CompileCase('source.mojo', 'a'*64, 0, defines=('FP_ASYNC_PROFILE=work_stealing',))
        argv = case.argv('out')
        self.assertEqual(argv[argv.index('-D') + 1], 'FP_ASYNC_PROFILE=work_stealing')
        self.assertNotIn('-D', CompileCase('source.mojo', 'a'*64, 0).argv('out'))

    def test_documentation_examples_take_defines(self):
        """`docs-test --define` builds every example with the define and records it."""
        import json
        from unittest import mock
        import verify_docs_examples as runner
        seen = []

        def execute(case, binary, prefix):
            seen.append(case)
            return dict(passed=True)
        with tempfile.TemporaryDirectory(dir=ROOT/'.cache') as temporary:
            output = Path(temporary)/'run'
            argv = ['docs-test', '--output', str(output), '--only', 'async_runtime',
                    '--define', 'FP_ASYNC_PROFILE=work_stealing']
            with mock.patch.object(sys, 'argv', argv), \
                    mock.patch.object(runner, 'precompile', return_value=dict(returncode=0)), \
                    mock.patch.object(runner, 'accepted', return_value=True), \
                    mock.patch.object(runner, 'library_inputs', return_value={}), \
                    mock.patch.object(runner, 'library_binding', return_value={}), \
                    mock.patch.object(runner, 'audit_library_binding', return_value=[]), \
                    mock.patch.object(runner, 'execute_case', side_effect=execute), \
                    mock.patch.object(runner, 'audit_case', return_value=[]):
                runner.main()
            report = json.loads((output/'report.json').read_text())
        self.assertEqual(len(seen), 4)
        self.assertTrue(all(c.defines == ('FP_ASYNC_PROFILE=work_stealing',) for c in seen))
        self.assertEqual(report['defines'], ['FP_ASYNC_PROFILE=work_stealing'])

    def test_output_reuse(self):
        with tempfile.TemporaryDirectory(dir=ROOT/'.cache') as temporary:
            folder = reserve_output(Path(temporary)/'run')
            with self.assertRaises(FileExistsError):
                reserve_output(folder)


if __name__ == '__main__':
    unittest.main()
