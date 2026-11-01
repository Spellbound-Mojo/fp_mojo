"""Retained evidence: summary schema, retention after a passing audit, committed summaries."""
from dataclasses import asdict
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock
sys.path.insert(0, str(Path(__file__).resolve().parents[2]/'scripts'))
sys.path.insert(0, str(Path(__file__).resolve().parents[2]/'experiments/async-state-machines'))
from fp_tools import evidence
from fp_tools.cases import CompileCase
from fp_tools.runtime import ROOT

HOST = dict(compiler='Mojo 1.2.0 (2016d0cd)', platform='Linux', machine='x86_64', cpu='Test CPU')


def report(passed=True):
    spec = asdict(CompileCase('docs/examples/x.mojo', 'a'*64, 3, defines=('FP_ASYNC_PROFILE=work_stealing',)))
    record = dict(route='source', specification=spec, passed=passed, audit_failures=[],
                  executable_sha256='b'*64, execution=dict(stdout='42\n'))
    return dict(HOST, inputs={'src/a.mojo': 'c'*64, evidence.EVIDENCE_PREFIX + 'old.json': 'd'*64},
                records=[record], passed=passed)


class EvidenceTests(unittest.TestCase):
    def summary(self):
        return evidence.summarize('documentation-examples', 'docs-pool', report(), 'e'*64, 'f'*40, 'load 1.2')

    def test_summary_schema(self):
        summary = self.summary()
        self.assertEqual(evidence.validate(summary), [])
        self.assertEqual(summary['defines'], ['FP_ASYNC_PROFILE=work_stealing'])
        self.assertEqual(summary['records'][0]['name'], 'x-source-O3')
        self.assertEqual(summary['input_files'], 1, 'retained summaries are not inputs of the run')
        for change in ({'label': 'Bad Label'}, {'source_commit': 'abc'}, {'report_sha256': 'x'},
                       {'kind': 'other'}, {'checks': 2}, {'host': {}}, {'defines': ['B=1', 'A=1']},
                       {'format_version': 2}, {'extra': 1}):
            broken = dict(summary, **change)
            self.assertTrue(evidence.validate(broken), change)
        failed = dict(summary, records=[dict(summary['records'][0], passed=False)], passed=0)
        self.assertIn('a retained qualification must have passed every check', evidence.validate(failed))

    def test_retain_writes_only_after_a_passing_audit(self):
        with tempfile.TemporaryDirectory(dir=ROOT/'.cache') as temporary:
            bundle, out = Path(temporary)/'bundle', Path(temporary)/'evidence'
            bundle.mkdir()
            (bundle/'report.json').write_text(json.dumps(report()))
            current = {'src/a.mojo': 'c'*64, evidence.EVIDENCE_PREFIX + 'new.json': '0'*64}
            with mock.patch.object(evidence, 'inputs', return_value=current), \
                    mock.patch.object(evidence, 'checkout', return_value='f'*40):
                failures = evidence.retain('documentation-examples', 'docs-pool', bundle,
                                           lambda r, f: ['raw log changed'], directory=out)
                self.assertEqual(failures, ['raw log changed'])
                self.assertFalse((out/'docs-pool.json').exists())
                self.assertEqual(evidence.retain('documentation-examples', 'docs-pool', bundle,
                                                 lambda r, f: [], directory=out), [])
                written = json.loads((out/'docs-pool.json').read_text())
                self.assertEqual(evidence.validate(written), [])
                self.assertEqual(written['report_sha256'], evidence.sha(bundle/'report.json'))
                with self.assertRaises(FileExistsError):
                    evidence.retain('documentation-examples', 'docs-pool', bundle, lambda r, f: [], directory=out)
            changed = {'src/a.mojo': '1'*64}
            with mock.patch.object(evidence, 'inputs', return_value=changed), \
                    mock.patch.object(evidence, 'checkout', return_value='f'*40):
                failures = evidence.retain('documentation-examples', 'other', bundle, lambda r, f: [], directory=out)
            self.assertIn('the checkout differs from the inputs the run recorded', failures)

    def test_qualify_rebuilds_cases_from_records(self):
        import qualify
        case = CompileCase('tests/x.mojo', 'a'*64, 0, reject=('error',),
                           defines=('FP_ASYNC_PROFILE=current_thread',))
        self.assertEqual(qualify.case_of(json.loads(json.dumps(asdict(case)))), case)

    def test_committed_summaries_validate(self):
        for label, summary in evidence.retained().items():
            self.assertEqual(summary['label'], label)
            self.assertEqual(evidence.validate(summary), [], label)


if __name__ == '__main__':
    unittest.main()
