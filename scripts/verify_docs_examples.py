"""Compile and execute the exact documentation programs on both import routes."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict
from pathlib import Path

from docs_contract import data
from fp_tools.artifacts import manifest, library_inputs, library_binding, audit_library_binding, audit as audit_artifacts
from fp_tools.cases import CompileCase, execute_case, audit_case
from fp_tools.evidence import run_inputs
from fp_tools.runs import RunContext, audit_run_paths
from fp_tools.library import precompile
from fp_tools.runtime import ROOT, accepted, inputs, sha, write_json, positive_int


def audit_report(report, folder):
    """Re-derive a finished run's outcomes from its raw evidence, in the same checkout."""
    failures = []
    try:
        folder = Path(folder).resolve()
        binaries = audit_run_paths(report, folder)
        if run_inputs(report['inputs']) != run_inputs(inputs()) or report.get('inputs_unchanged') is not True:
            raise ValueError('changed immutable documentation inputs')
        if report['manifest_sha256'] != sha(ROOT / 'docs/examples.json'):
            raise ValueError('changed example manifest')
        if not accepted(report['package_compilation']):
            raise ValueError('package compilation evidence')
        declared = data('examples.json')['examples']
        records = report['records']
        if not records or [[r['source'], r['route'], r['optimization']] for r in records] != report['declared_inventory']:
            raise ValueError('records differ from the declared inventory')
        for record in records:
            values = dict(record['specification'])
            values['defines'] = tuple(values.get('defines', ()))
            case = CompileCase(**values)
            expected = CompileCase.from_source(
                record['source'], record['optimization'], include=case.include, werror=True,
                expected_stdout=declared[record['source']]['stdout'], compile_timeout=case.compile_timeout,
                defines=case.defines)
            if case != expected:
                raise ValueError(f"{record['source']}: specification differs from the reviewed example")
            name = record['source'].replace('/', '_').removesuffix('.mojo') + f"-{record['route']}-O{record['optimization']}"
            errors = audit_case(case, record, binaries / name, folder=folder)
            if errors or not record['passed'] or record['audit_failures']:
                raise ValueError(name + ': ' + '; '.join(errors or record['audit_failures'] or ['failed']))
        failures += audit_library_binding(report, include=folder / 'package', expected_inputs=report['library_inputs'])
        failures += audit_artifacts(report, folder)
    except (ValueError, KeyError, TypeError, OSError, AttributeError) as error:
        failures.append(str(error))
    return failures


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True, help='A fresh retained evidence directory')
    parser.add_argument('--only', help='Development-only source substring')
    parser.add_argument('--compile-timeout', type=positive_int, default=180,
                        help='Seconds per package/program compilation (default: 180)')
    parser.add_argument('--jobs', type=positive_int, default=2,
                        help='Concurrent example compilations (default: 2)')
    parser.add_argument('--define', action='append', default=[], metavar='NAME=VALUE',
                        help='Compile-time define for every example, such as '
                             'FP_ASYNC_PROFILE=work_stealing; repeatable')
    args = parser.parse_args()
    context = RunContext.start(args.output, 'docs-examples')
    folder = context.folder
    declared = data('examples.json')['examples']
    selected = {p: spec for p, spec in declared.items() if not args.only or args.only in p}
    assert selected, 'No matching documentation programs'
    package = folder / 'package'
    package.mkdir()
    built = precompile(package / 'fp.mojoc', folder / 'package.log', timeout=args.compile_timeout)
    assert accepted(built), 'Package compilation failed'
    packaged = library_inputs(package)
    tasks = []
    for path, spec in selected.items():
        for route in ('source', 'package'):
            for level in (0, 3):
                case = CompileCase.from_source(path, level, include='src' if route == 'source' else str(package),
                                               werror=True, expected_stdout=spec['stdout'],
                                               compile_timeout=args.compile_timeout,
                                               defines=tuple(args.define))
                tasks.append((path, route, level, case))
    def execute(task):
        path, route, level, case = task
        name = path.replace('/', '_').removesuffix('.mojo') + f'-{route}-O{level}'
        binary = context.binaries / name
        row = execute_case(case, binary, folder / 'runs' / name)
        failures = audit_case(case, row, binary, folder=folder)
        print('PASS' if row['passed'] and not failures else 'FAIL', name, flush=True)
        return dict(source=path, route=route, optimization=level, specification=asdict(case), **row,
                    audit_failures=failures)
    with ThreadPoolExecutor(max_workers=args.jobs) as executor:
        records = list(executor.map(execute, tasks))
    binding = library_binding(package, packaged)
    library_failures = audit_library_binding(binding, include=package, expected_inputs=packaged)
    passed = (all(r['passed'] and not r['audit_failures'] for r in records)
              and inputs() == context.before and not library_failures)
    report = dict(**context.metadata(), **binding, full_inventory=not args.only,
                  compile_timeout=args.compile_timeout, jobs=args.jobs, defines=args.define,
                  manifest_sha256=sha(ROOT / 'docs/examples.json'),
                  declared_inventory=[[p, r, o] for p, r, o, _ in tasks],
                  sources={p: sha(ROOT / p) for p in declared}, package_compilation=built,
                  records=records, passed=passed, audit_failures=library_failures)
    report['artifact_sha256'] = manifest(folder)
    write_json(folder / 'report.json', report)
    print('DOCUMENTATION EXAMPLES PASS' if passed else 'FAILED', flush=True)
    return not passed


if __name__ == '__main__':
    raise SystemExit(main())
