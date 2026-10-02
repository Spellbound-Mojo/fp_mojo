"""The combined suite: generated drivers, raw-log outcomes and a fail-closed audit."""
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[2]/'scripts'))
from fp_tools.runtime import ROOT, PIN, sha
from suite_contract import (MARK, audit_report, benchmark_rows, build_argv, check_module_names,
                            driver_source, fold_runs, inventory, judge, parse_run, run_argv)

PROGRAMS = {
    'tests/runtime/test_alpha.mojo': 'def main() raises:\n    pass\n',
    'tests/runtime/test_zeta.mojo': 'def main():\n    pass\n',
    'tests/ownership/test_alpha.mojo': 'def main() raises:\n    pass\n',
    'docs/examples/hello.mojo': 'def main():\n    print("hi")\n',
    'tests/benchmarks/bench_x.mojo': 'def main():\n    pass\n',
}


def begin(i, path): return f'{MARK} begin {i} {path}\n'
def passed(i): return f'{MARK} pass {i} 7\n'
END = f'{MARK} end\n'


class SuiteContractTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(dir=ROOT/'.cache'); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for path, body in PROGRAMS.items():
            p = self.root/path; p.parent.mkdir(parents=True, exist_ok=True); p.write_text(body)
        (self.root/'docs/examples.json').write_text(json.dumps(
            dict(version=1, examples={'docs/examples/hello.mojo': dict(stdout='hi\n')})))

    def test_inventory_groups_programs_into_executables(self):
        rows = inventory(root=self.root)
        self.assertEqual([(r['path'], r['shard'], r['kind']) for r in rows], [
            ('tests/runtime/test_alpha.mojo', 'runtime-1', 'test'),
            ('tests/runtime/test_zeta.mojo', 'runtime-2', 'test'),
            ('tests/ownership/test_alpha.mojo', 'ownership', 'test'),
            ('docs/examples/hello.mojo', 'integration', 'example'),
            ('tests/benchmarks/bench_x.mojo', 'integration', 'benchmark')])
        self.assertEqual(rows[3]['stdout'], 'hi\n')
        self.assertEqual([r['path'] for r in inventory('zeta', self.root)], ['tests/runtime/test_zeta.mojo'])

    def test_module_names_are_unambiguous_per_executable(self):
        self.assertEqual(check_module_names(self.root), [])
        (self.root/'tests/laws').mkdir(); (self.root/'tests/laws/hello.mojo').write_text('')
        problems = check_module_names(self.root)
        self.assertEqual(len(problems), 1); self.assertIn('module hello', problems[0])

    def test_driver_calls_each_main_between_markers(self):
        modules = [r for r in inventory(root=self.root) if r['shard'] == 'integration']
        text = driver_source('integration', modules, self.root)
        self.assertIn('import hello\nimport bench_x\n', text)
        self.assertIn(f'print("{MARK} begin 0 docs/examples/hello.mojo", flush=True)\n        clock = perf_counter_ns()\n        hello.main()', text)
        self.assertNotIn('try:', text)  # neither main raises
        raising = driver_source('runtime-1', inventory('alpha', self.root)[:1], self.root)
        self.assertIn(f'        except error:\n            print("{MARK} fail 0", error, flush=True)', raising)
        self.assertEqual(build_argv('pkg', 'integration', 'd.mojo', 'exe', False)[2:6], ['-I', 'pkg', '-I', 'tests/integration'])
        self.assertEqual(run_argv('exe', 0), ['exe']); self.assertEqual(run_argv('exe', 2), ['exe', '--from', '2'])

    def test_outcomes_come_from_markers_and_restarts(self):
        modules = [dict(path=p, kind='test') for p in ('a', 'b', 'c')]
        whole = begin(0, 'a') + 'out\n' + passed(0) + begin(1, 'b') + f'{MARK} fail 1 bad\nline\n' + begin(2, 'c') + passed(2) + END
        results, stopped, ended = parse_run(whole)
        self.assertEqual((stopped, ended, results[0]['output'], results[1]['error']), (None, True, 'out\n', 'bad\nline'))
        ok = dict(command=['exe'], exit_code=0, timeout=False, crashed=False, stdout=whole, stderr='')
        self.assertEqual([o['passed'] for o in fold_runs(modules, [ok])], [True, False, True])
        crash = dict(ok, stdout=begin(0, 'a') + passed(0) + begin(1, 'b'), exit_code=-6, crashed=True)
        rest = dict(ok, command=['exe', '--from', '2'], stdout=begin(2, 'c') + passed(2) + END)
        folded = fold_runs(modules, [crash, rest])
        self.assertEqual([o['passed'] for o in folded], [True, False, True])
        self.assertIn('crashed', folded[1]['error'])
        early = dict(crash, stdout=begin(0, 'a') + passed(0))  # died between programs
        self.assertEqual([o['error'] for o in fold_runs(modules, [early])], [None, 'not run', 'not run'])
        for runs in ([crash, dict(rest, command=['exe', '--from', '1'])],  # wrong restart
                     [dict(ok, stdout=whole.replace(END, ''))],             # exit 0 without the end marker
                     [dict(ok, stdout=begin(1, 'b') + passed(1) + END)],    # skipped a program
                     [dict(ok, stdout=begin(0, 'x') + passed(0) + END)]):   # wrong identity
            with self.assertRaises(ValueError):
                fold_runs(modules, runs)
        with self.assertRaises(ValueError):
            parse_run(begin(0, 'a') + begin(1, 'b'))

    def test_examples_and_benchmarks(self):
        example = dict(path='e', kind='example', stdout='hi\n')
        self.assertIsNone(judge(example, dict(passed=True, output='hi\n')))
        self.assertIn('reviewed output', judge(example, dict(passed=True, output='hello\n')))
        rows = benchmark_rows(dict(path='b'), dict(output='bench m native_ns=100 library_ns=150 samples=9\n'))
        self.assertEqual(rows, [dict(program='b', name='m', native_ns=100, library_ns=150, samples=9, ratio=1.5)])

    def good_report(self):
        folder = self.root/'run'; binaries = folder/'executables/suite-x'; binaries.mkdir(parents=True)
        (folder/'drivers').mkdir(); modules = inventory(root=self.root); shards = []
        def record(name, argv, stdout):
            log = folder/'logs'/f'{name}.log'; log.parent.mkdir(exist_ok=True); log.write_text(stdout)
            return dict(command=argv, exit_code=0, timeout=False, crashed=False, stdout=stdout, stderr='', log=str(log))
        rows = []
        for name in ('runtime-1', 'runtime-2', 'ownership', 'integration'):
            members = [m for m in modules if m['shard'] == name]
            driver = folder/'drivers'/f'suite_{name.replace("-", "_")}.mojo'; driver.write_text(driver_source(name, members, self.root))
            executable = binaries/f'fp-suite-{name}'; executable.write_text('binary')
            out = ''.join(begin(i, m['path']) + (m.get('stdout') or '') + passed(i) for i, m in enumerate(members)) + END
            shards.append(dict(name=name, driver=str(driver), driver_sha256=sha(driver), executable=str(executable),
                               executable_sha256=sha(executable), compilation=record(name + '.build', build_argv('src', name, driver, executable, False), ''),
                               runs=[record(name + '.run0', [str(executable)], out)]))
            rows += [dict(path=m['path'], shard=name, kind=m['kind'], passed=True, error=None, nanoseconds=7) for m in members]
        report = dict(report_version=2, output_directory=str(folder), binary_directory=str(binaries), compiler=PIN,
                      include='src', filter='', werror=False, optimization=3, inputs={'x': 'y'}, input_changes=[], inputs_unchanged=True,
                      shards=shards, modules=rows, benchmarks=[], passed=True)
        return report, dict(folder=folder, include='src', expected_inputs={'x': 'y'}, root=self.root)

    def test_audit_accepts_consistent_evidence_and_rejects_corruption(self):
        good, contract = self.good_report()
        self.assertEqual(audit_report(good, **contract), [])
        def outcome(r): r['modules'][0]['passed'] = False
        def conclusion(r): r['passed'] = False
        def dropped(r): r['modules'].pop()
        def driver(r): Path(r['shards'][0]['driver']).write_text('changed')
        def argv(r): r['shards'][0]['compilation']['command'][4] = '-O0'
        def executable(r): r['shards'][0]['executable_sha256'] = 'wrong'
        def raw_log(r): r['shards'][1]['runs'][0]['stdout'] += 'extra'
        def example(r):
            run = r['shards'][3]['runs'][0]; run['stdout'] = run['stdout'].replace('hi\n', 'ho\n')
            Path(run['log']).write_text(run['stdout'])
        def benchmark(r): r['benchmarks'] = [dict(name='invented')]
        def inputs(r): r['input_changes'] = ['x']
        def werror(r): r['werror'] = True
        def level(r): r['optimization'] = 0
        for mutate in (outcome, conclusion, dropped, driver, argv, executable, raw_log, example, benchmark, inputs, werror, level):
            with self.subTest(mutation=mutate.__name__):
                shutil.rmtree(self.root/'run')
                report, contract = self.good_report()
                mutate(report)
                self.assertTrue(audit_report(report, **contract))

if __name__ == '__main__':
    unittest.main()
