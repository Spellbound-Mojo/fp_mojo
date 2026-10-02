"""Compile and execute the exact documentation programs on both import routes."""
import argparse
from concurrent.futures import ThreadPoolExecutor

from docs_contract import data
from fp_tools.artifacts import manifest
from fp_tools.cases import CompileCase, execute_case, audit_case
from fp_tools.runs import RunContext
from fp_tools.library import precompile
from fp_tools.runtime import ROOT, accepted, inputs, sha, write_json, positive_int


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True, help='A fresh retained evidence directory')
    parser.add_argument('--only', help='Development-only source substring')
    parser.add_argument('--compile-timeout', type=positive_int, default=180,
                        help='Seconds per package/program compilation (default: 180)')
    parser.add_argument('--jobs', type=positive_int, default=2,
                        help='Concurrent example compilations (default: 2)')
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
    tasks = []
    for path, spec in selected.items():
        for route in ('source', 'package'):
            for level in (0, 3):
                case = CompileCase.from_source(path, level, include='src' if route == 'source' else str(package),
                                               werror=True, expected_stdout=spec['stdout'],
                                               compile_timeout=args.compile_timeout)
                tasks.append((path, route, level, case))
    def execute(task):
        path, route, level, case = task
        name = path.replace('/', '_').removesuffix('.mojo') + f'-{route}-O{level}'
        binary = context.binaries / name
        row = execute_case(case, binary, folder / 'runs' / name)
        failures = audit_case(case, row, binary, folder=folder)
        print('PASS' if row['passed'] and not failures else 'FAIL', name, flush=True)
        return dict(source=path, route=route, optimization=level, **row, audit_failures=failures)
    with ThreadPoolExecutor(max_workers=args.jobs) as executor:
        records = list(executor.map(execute, tasks))
    passed = all(r['passed'] and not r['audit_failures'] for r in records) and inputs() == context.before
    report = dict(**context.metadata(), full_inventory=not args.only,
                  compile_timeout=args.compile_timeout, jobs=args.jobs,
                  manifest_sha256=sha(ROOT / 'docs/examples.json'),
                  declared_inventory=[[p, r, o] for p, r, o, _ in tasks],
                  sources={p: sha(ROOT / p) for p in declared}, package_compilation=built,
                  records=records, passed=passed)
    report['artifact_sha256'] = manifest(folder)
    write_json(folder / 'report.json', report)
    print('DOCUMENTATION EXAMPLES PASS' if passed else 'FAILED', flush=True)
    return not passed


if __name__ == '__main__':
    raise SystemExit(main())
