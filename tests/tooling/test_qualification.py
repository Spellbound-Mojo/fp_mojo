"""Failures in qualification must fail closed, including expected-reject crashes."""
import sys
from pathlib import Path
import tempfile
from concurrent.futures import ThreadPoolExecutor
import threading
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
from fp_tools.runtime import (ROOT, accepted, binary_directory, command, input_changes,
                           inputs, reserve_output)


class QualificationTests(unittest.TestCase):
    def test_outcomes(self):
        good = dict(timeout=False, crashed=False, exit_code=0, stdout='', stderr='')
        self.assertTrue(accepted(good))
        self.assertFalse(accepted(good, ['expected error']))
        bad = good | dict(exit_code=1, stderr='expected error')
        self.assertTrue(accepted(bad, ['expected error']))
        self.assertFalse(accepted(bad, []))
        self.assertFalse(accepted(bad, ['']))
        self.assertFalse(accepted(bad, ['wrong error']))
        self.assertFalse(accepted(bad | dict(crashed=True), ['expected error']))
        self.assertFalse(accepted(bad | dict(timeout=True), ['expected error']))
        self.assertFalse(accepted(bad | dict(exit_code=-9), ['expected error']))
        for stream in ('stdout', 'stderr'):
            for fatal in ('LLVM ERROR: synthetic', 'Assertion x failed', 'Segmentation fault'):
                self.assertFalse(accepted(bad | {stream: 'expected error\n' + fatal}, ['expected error']))
        self.assertFalse(accepted({}))

    def test_process_and_timeout(self):
        with tempfile.TemporaryDirectory(dir=ROOT / '.cache') as folder:
            log = Path(folder) / 'process.log'
            result = command([sys.executable, '-c', 'print("ok")'], log)
            self.assertTrue(accepted(result))
            self.assertEqual(result['stdout'], 'ok\n')
            result = command([sys.executable, '-c', 'import time; time.sleep(5)'], log, timeout=0.1)
            self.assertFalse(accepted(result))
            self.assertTrue(result['timeout'])
            self.assertIn('TIMEOUT', log.read_text())
            result = command([sys.executable, '-c', 'print("Stack dump: expected error"); exit(1)'], log)
            self.assertFalse(accepted(result, ['expected error']))

    @unittest.skipUnless(sys.platform == 'linux', 'Linux RSS budget')
    def test_memory_budget_is_an_unsuccessful_auditable_outcome(self):
        from fp_tools.runtime import audit_command
        with tempfile.TemporaryDirectory(dir=ROOT / '.cache') as folder:
            result = command([sys.executable, '-c',
                              'import time; data=bytearray(64*1024*1024); time.sleep(5)'],
                             Path(folder)/'memory.log', memory_limit_bytes=32*1024*1024)
            self.assertTrue(result['memory_limit_exceeded'])
            self.assertFalse(result['timeout'])
            self.assertFalse(accepted(result))
            self.assertTrue(audit_command(result))

    def test_document_inputs_and_changes(self):
        with tempfile.TemporaryDirectory(dir=ROOT / '.cache') as folder:
            root = Path(folder)
            for name in ('README.md', 'pixi.toml', 'pixi.lock',
                         'docs/content/index.md', 'docs/examples.json'):
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('before')
            before = inputs(root)
            self.assertIn('docs/content/index.md', before)
            self.assertIn('docs/examples.json', before)
            self.assertEqual(input_changes(before, inputs(root)), [])
            (root / 'docs/content/index.md').write_text('after')
            (root / 'README.md').unlink()
            (root / 'docs/content/new.md').write_text('new')
            # Required inputs disappearing must also fail qualification.
            with self.assertRaises(FileNotFoundError):
                inputs(root)
            (root / 'README.md').write_text('before')
            self.assertEqual(input_changes(before, inputs(root)), ['docs/content/index.md', 'docs/content/new.md'])
            self.assertEqual(input_changes({'removed': 'hash'}, {}), ['removed'])

    def test_concurrent_runs_cannot_share_executables_or_report_directory(self):
        with tempfile.TemporaryDirectory(dir=ROOT / '.cache') as folder:
            parent = Path(folder)
            rendezvous = threading.Barrier(2)
            def execute(token):
                report = reserve_output(parent / token)
                binaries = binary_directory(report, 'concurrency-test')
                self.assertTrue(binaries.is_relative_to(report / "executables"))
                executable = binaries / 'same-name'
                executable.write_text(f'print({token!r})\n')
                rendezvous.wait(timeout=10)
                result = command([sys.executable, executable], report / 'run.log')
                return executable, result
            with ThreadPoolExecutor(max_workers=2) as pool:
                results = list(pool.map(execute, ('first', 'second')))
            self.assertNotEqual(results[0][0], results[1][0])
            self.assertTrue(all(accepted(r) for _, r in results))
            self.assertEqual([r['stdout'] for _, r in results], ['first\n', 'second\n'])
            def reserve(_):
                try:
                    reserve_output(parent / 'collision')
                    return True
                except FileExistsError:
                    return False
            with ThreadPoolExecutor(max_workers=2) as pool:
                self.assertEqual(sorted(pool.map(reserve, range(2))), [False, True])


if __name__ == '__main__':
    unittest.main()
