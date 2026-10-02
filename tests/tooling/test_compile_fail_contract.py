"""Synthetic corruption of compile-failure evidence must fail closed."""
import copy
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'scripts'))
from fp_tools.runtime import ROOT, PIN, sha
from compile_fail_contract import audit_report, inventory


class CompileFailContractTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(dir=ROOT/'.cache');self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name)
        for path,body in [('tests/runtime/test_control.mojo','def main(): pass\n'),('tests/compile_fail/test_control.mojo','# error: expected rejection\n'),('tests/compile_fail/test_control_b.mojo','# error: expected rejection\n')]:
            p=self.root/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(body)
        self.binaries=self.root/'run/executables/fresh-unique';self.binaries.mkdir(parents=True)
        self.contract=dict(root=self.root,folder=self.root/'run',optimization=3,include='src',filter='control',werror=True,expected_inputs={'source':'hash'})
        rows=[]
        for path in inventory('control',self.root):
            source=self.root/path
            artifact=self.binaries/path.replace('/','_').removesuffix('.mojo');artifact.write_text('synthetic binary')
            argv=['mojo','build','-I','src','-O3','--Werror',path,'-o',str(artifact)]
            compiled=self.command(path+'.compile',argv,1,'expected rejection')
            rows.append(dict(path=path,sha256=sha(source),passed=True,command=argv,expected_errors=['expected rejection'],compilation=compiled,execution=None,executable_sha256=None))
        self.good=dict(report_version=2,output_directory=str(self.root/'run'),inputs_unchanged=True,compiler=PIN,optimization='3',include='src',filter='control',werror=True,tests=rows,declared_inventory=inventory('control',self.root),binary_directory=str(self.binaries),inputs={'source':'hash'},input_changes=[])

    def command(self,name,argv,code,err):
        log=self.root/'run'/(name+'.log');log.parent.mkdir(parents=True,exist_ok=True);log.write_text(err)
        return dict(command=argv,exit_code=code,timeout=False,crashed=False,stdout='',stderr=err,log=str(log))

    def test_valid_strict_and_ordinary(self):
        self.assertEqual(audit_report(self.good,**self.contract),[])
        self.good.update(filter='',werror=False)
        for row in self.good['tests']:
            row['compilation']['command'].remove('--Werror') # also shared row command
        self.assertEqual(audit_report(self.good,**(self.contract|dict(filter='',werror=False))),[])

    def test_bounded_compilation_policy(self):
        self.assertEqual(audit_report(self.good | dict(compile_timeout=1800), **self.contract), [])
        for timeout in (0, -1, True, None, '1800', 1.5):
            with self.subTest(timeout=timeout):
                failures = audit_report(self.good | dict(compile_timeout=timeout), **self.contract)
                self.assertIn('invalid compilation timeout', failures)

    def test_inventories_metadata_sources_and_executions(self):
        for mutation in ('missing','duplicate','declared','runtime-fixture','inputs','changes','source','level','route','warning','command','diagnostic','accepted-negative','negative-executed','truncated','flags'):
            with self.subTest(mutation=mutation):
                r=copy.deepcopy(self.good);first=r['tests'][0];negative=r['tests'][1]
                if mutation=='missing':r['tests'].pop()
                elif mutation=='duplicate':r['tests'][1]=first
                elif mutation=='declared':r['declared_inventory'].pop()
                elif mutation=='inputs':r['inputs']={}
                elif mutation=='changes':r['input_changes']=['source']
                elif mutation=='source':first['sha256']='changed'
                elif mutation=='level':r['optimization']='0'
                elif mutation=='route':r['include']='wrong'
                elif mutation=='warning':r['werror']=False
                elif mutation=='command':first['compilation']['command'][4]='-O0'
                elif mutation=='runtime-fixture':first['path']='tests/runtime/test_control.mojo'
                elif mutation=='diagnostic':negative['compilation']['stderr']='unrelated'
                elif mutation=='accepted-negative':negative['compilation']['exit_code']=0
                elif mutation=='negative-executed':negative['execution']=dict(negative['compilation'])
                elif mutation=='truncated':del first['compilation']['stdout']
                elif mutation=='flags':first['passed']=False
                self.assertTrue(audit_report(r,**self.contract))

    def test_fatal_diagnostics_timeouts_and_raw_logs(self):
        for row in range(2):
            for change in (dict(stderr='expected rejection\nLLVM ERROR: synthetic'),dict(timeout=True),dict(crashed=True),dict(exit_code=-9),dict(exit_code=False)):
                r=copy.deepcopy(self.good);r['tests'][row]['compilation'].update(change)
                self.assertTrue(audit_report(r,**self.contract),(row,change))
        (self.root/self.good['tests'][0]['compilation']['log']).write_text('truncated log')
        self.assertTrue(audit_report(self.good,**self.contract))


if __name__=='__main__':unittest.main()
