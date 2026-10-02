"""Check that every compile-failure fixture is rejected with its declared diagnostics.

Fixtures compile in parallel, each on its own, because a batch reports only the
first failing compiler phase. Contracts are reconstructed independently.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import os
import re
import sys
import uuid

from fp_tools.cases import CompileCase, execute_case
from fp_tools.library import add_library_arguments, library_include
from fp_tools.runs import RunContext
from fp_tools.runtime import ROOT, write_json, positive_int
from compile_fail_contract import audit_report, inventory


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    add_library_arguments(parser)
    parser.add_argument('--filter', default='')
    parser.add_argument('--optimization', choices=['0', '3'], default='3')
    parser.add_argument('--output')
    parser.add_argument('--werror', action='store_true')
    parser.add_argument('--jobs', type=positive_int, default=os.cpu_count() or 1,
                        help='Concurrent fixture compilations (default: one per CPU)')
    parser.add_argument('--compile-timeout', type=positive_int, default=180,
                        help='Seconds per fixture compilation (default: 180)')
    args = parser.parse_args()
    declared = inventory(args.filter)
    if not declared:
        parser.error('No fixtures selected')
    run = RunContext.start(args.output or f'.cache/compile-fail/{uuid.uuid4().hex}', 'compile-fail')
    include, package = library_include(args, run.folder)
    cases = [CompileCase.from_source(path, int(args.optimization), include=include, werror=args.werror,
                                     reject=tuple(re.findall(r'^# error: (.+)$', (ROOT / path).read_text(), re.M)),
                                     compile_timeout=args.compile_timeout)
             for path in declared]
    print(run.host['compiler'], f'- {len(cases)} fixtures against {include}', flush=True)

    def check(case):
        name = case.source.replace('/', '_').removesuffix('.mojo')
        artifact = run.binaries / name
        outcome = execute_case(case, artifact, run.folder / name)
        if not outcome['passed']:
            compiled = outcome['compilation']
            print(f'FAIL {case.source}\n' + (compiled['stdout'] + compiled['stderr'])[-8000:], flush=True)
        return dict(path=case.source, sha256=case.source_sha256, command=case.argv(artifact),
                    expected_errors=list(case.reject), **outcome)

    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        records = list(pool.map(check, cases))
    report = dict(**run.metadata(), optimization=args.optimization, filter=args.filter,
                  include=include, package_compilation=package, werror=args.werror,
                  compile_timeout=args.compile_timeout, jobs=args.jobs,
                  tests=records, declared_inventory=declared)
    audit = audit_report(report, folder=run.folder, optimization=args.optimization, include=include,
                         filter=args.filter, werror=args.werror, expected_inputs=run.before)
    report['audit_failures'] = audit
    write_json(run.folder / 'report.json', report)
    failures = sum(not item['passed'] for item in records)
    print(f'{len(records) - failures}/{len(records)} rejected as declared; {len(audit)} audit failures')
    for failure in audit:
        print('AUDIT', failure)
    return bool(failures or audit)


if __name__ == '__main__':
    sys.exit(main())
