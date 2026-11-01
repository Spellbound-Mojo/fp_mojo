"""Retained qualification evidence: committed summaries of audited run bundles.

A run bundle (a runner's fresh output directory) stays in the checkout that
produced it; executables and raw logs are too large to commit. A summary
binds the bundle by the SHA-256 of its final report, the digest of the input
hashes the report recorded, and the source commit whose tree reproduces those
inputs. Summaries are written only after the runner's own auditor has
re-derived every outcome from the raw evidence, and only from a clean
checkout whose inputs equal the run's. The summaries themselves are left out
of that comparison, so several bundles of one gate can be retained in turn
before their summaries are committed together.
"""
import hashlib
import json
import re
import subprocess

from .runtime import ROOT, inputs, sha

FORMAT_VERSION = 1
DIRECTORY = ROOT / 'docs/content/architecture/evidence'
KINDS = ('qualification', 'stress', 'documentation-examples')
HOST_KEYS = ('compiler', 'platform', 'machine', 'cpu')
_HEX = re.compile(r'[0-9a-f]{64}')
_COMMIT = re.compile(r'[0-9a-f]{40}')
_LABEL = re.compile(r'[a-z0-9][a-z0-9-]{0,79}')


EVIDENCE_PREFIX = 'docs/content/architecture/evidence/'


def run_inputs(snapshot):
    """Input hashes without retained summaries, which are written after the run."""
    return {path: value for path, value in snapshot.items() if not path.startswith(EVIDENCE_PREFIX)}


def digest(mapping):
    """The SHA-256 of a mapping's canonical JSON, such as a report's input hashes."""
    return hashlib.sha256(json.dumps(mapping, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def checkout(root=ROOT):
    """The commit whose tree is checked out, provided no tracked or new file differs."""
    status = subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=all', '--', '.',
                                      ':(exclude)' + EVIDENCE_PREFIX], cwd=root, text=True)
    if status.strip():
        raise ValueError('the checkout has uncommitted changes, so no commit reproduces its inputs')
    return subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()


def _stdout_sha(record):
    execution = record.get('execution') or {}
    stdout = execution.get('stdout')
    return hashlib.sha256(stdout.encode()).hexdigest() if isinstance(stdout, str) else None


def _rows(kind, report):
    """One row per audited check: its name, outcome and output hashes."""
    if kind == 'stress':
        compilations = report['compilations']
        rows = [dict(name=f'{identity}-build', passed=True,
                     executable_sha256=record.get('executable_sha256'), stdout_sha256=_stdout_sha(record))
                for identity, record in sorted(compilations.items())]
        for group in ('soaks', 'performance'):
            rows += [dict(name=f'{identity}-{group}', passed=True, executable_sha256=None,
                          stdout_sha256=hashlib.sha256(record['stdout'].encode()).hexdigest())
                     for identity, record in sorted(report[group].items())]
        return rows
    rows = []
    for record in report['records']:
        spec = record['specification']
        stem = spec['source'].rsplit('/', 1)[-1].removesuffix('.mojo')
        name = f"{stem}-{record['route']}-O{spec['optimization']}"
        rows.append(dict(name=name, passed=bool(record['passed'] and not record['audit_failures']),
                         executable_sha256=record.get('executable_sha256'), stdout_sha256=_stdout_sha(record)))
    return rows


def _defines(kind, report):
    if kind == 'stress':
        return []
    return sorted({define for record in report['records']
                   for define in record['specification'].get('defines', ())})


def summarize(kind, label, report, report_sha256, commit, host_load=None):
    """The committed summary of an audited bundle."""
    rows = _rows(kind, report)
    summary = dict(
        format_version=FORMAT_VERSION, label=label, kind=kind, source_commit=commit,
        report_sha256=report_sha256, inputs_sha256=digest(run_inputs(report['inputs'])),
        input_files=len(run_inputs(report['inputs'])),
        experiment_inputs_sha256=(digest(report['experiment_inputs']) if 'experiment_inputs' in report else None),
        host={key: report[key] for key in HOST_KEYS}, host_load=host_load,
        defines=_defines(kind, report), checks=len(rows), passed=sum(r['passed'] for r in rows),
        records=rows)
    failures = validate(summary)
    if failures:
        raise ValueError('; '.join(failures))
    return summary


def validate(summary):
    """Schema and consistency of one summary, independent of any bundle."""
    failures = []
    try:
        expected = {'format_version', 'label', 'kind', 'source_commit', 'report_sha256', 'inputs_sha256',
                    'input_files', 'experiment_inputs_sha256', 'host', 'host_load', 'defines', 'checks',
                    'passed', 'records'}
        if set(summary) != expected:
            failures.append('missing or unknown summary fields')
            return failures
        if summary['format_version'] != FORMAT_VERSION:
            failures.append('unsupported format version')
        if summary['kind'] not in KINDS:
            failures.append('unknown evidence kind')
        if not isinstance(summary['label'], str) or not _LABEL.fullmatch(summary['label']):
            failures.append('label must be lowercase words joined by hyphens')
        if not isinstance(summary['source_commit'], str) or not _COMMIT.fullmatch(summary['source_commit']):
            failures.append('source commit must be a full SHA-1')
        for key in ('report_sha256', 'inputs_sha256'):
            if not isinstance(summary[key], str) or not _HEX.fullmatch(summary[key]):
                failures.append(f'{key} must be a SHA-256')
        experiment = summary['experiment_inputs_sha256']
        if experiment is not None and (not isinstance(experiment, str) or not _HEX.fullmatch(experiment)):
            failures.append('experiment_inputs_sha256 must be a SHA-256 or null')
        if type(summary['input_files']) is not int or summary['input_files'] <= 0:
            failures.append('input_files must be positive')
        if set(summary['host']) != set(HOST_KEYS) or not all(isinstance(v, str) and v for v in summary['host'].values()):
            failures.append('host must name compiler, platform, machine and cpu')
        if not isinstance(summary['defines'], list) or summary['defines'] != sorted(set(summary['defines'])):
            failures.append('defines must be a sorted list without repeats')
        records = summary['records']
        names = [r.get('name') for r in records]
        if not records or len(set(names)) != len(names):
            failures.append('records must be present and uniquely named')
        for row in records:
            if set(row) != {'name', 'passed', 'executable_sha256', 'stdout_sha256'} or type(row['passed']) is not bool:
                failures.append(f'malformed record {row.get("name")}')
                continue
            for key in ('executable_sha256', 'stdout_sha256'):
                if row[key] is not None and not _HEX.fullmatch(str(row[key])):
                    failures.append(f'{row["name"]}: {key} must be a SHA-256 or null')
        if summary['checks'] != len(records) or summary['passed'] != sum(r['passed'] for r in records):
            failures.append('check counts disagree with the records')
        if summary['passed'] != summary['checks']:
            failures.append('a retained qualification must have passed every check')
    except (AttributeError, TypeError, KeyError) as error:
        failures.append(f'malformed summary: {error}')
    return failures


def retain(kind, label, folder, auditor, *, root=ROOT, directory=DIRECTORY, host_load=None):
    """Re-audit a finished bundle with its runner's auditor, then write its summary.

    The auditor is the runner's own `audit_report(report, folder)`: each runner
    owns the rules for its report format. Nothing is written on any failure.
    """
    if kind not in KINDS:
        raise ValueError('unknown evidence kind')
    if not _LABEL.fullmatch(label):
        raise ValueError('label must be lowercase words joined by hyphens')
    target = directory / f'{label}.json'
    if target.exists():
        raise FileExistsError(f'evidence already retained: {target}')
    folder = folder.resolve()
    report_path = folder / 'report.json'
    report = json.loads(report_path.read_text())
    failures = list(auditor(report, folder))
    if report.get('passed') is not True:
        failures.append('the run did not pass')
    if run_inputs(report.get('inputs') or {}) != run_inputs(inputs(root)):
        failures.append('the checkout differs from the inputs the run recorded')
    commit = None
    try:
        commit = checkout(root)
    except ValueError as error:
        failures.append(str(error))
    if failures:
        return failures
    summary = summarize(kind, label, report, sha(report_path), commit, host_load)
    directory.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(summary, indent=2) + '\n')
    return []


def retained(directory=DIRECTORY):
    """Every committed summary, by label."""
    return {path.stem: json.loads(path.read_text()) for path in sorted(directory.glob('*.json'))}
