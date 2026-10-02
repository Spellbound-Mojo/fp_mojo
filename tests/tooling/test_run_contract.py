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
                       {'memory_limit_bytes':True}, {'measured':1}):
            values = dict(source='source.mojo', source_sha256='a'*64, optimization=0) | change
            with self.assertRaises(ValueError):
                CompileCase(**values)

    def test_output_reuse(self):
        with tempfile.TemporaryDirectory(dir=ROOT/'.cache') as temporary:
            folder = reserve_output(Path(temporary)/'run')
            with self.assertRaises(FileExistsError):
                reserve_output(folder)


if __name__ == '__main__':
    unittest.main()
