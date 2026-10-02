"""Run every test, documentation example and benchmark against one fp library.

The programs are grouped into four executables, built in parallel into one
directory and run one after another as a single suite, at O3 by default. Benchmarks are
diagnostics: they are reported and never fail the suite. Compile-failure
fixtures are checked separately by scripts/compile_fail.py.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import sys
import uuid

from fp_tools.library import add_library_arguments, library_include
from fp_tools.runs import RunContext
from fp_tools.runtime import accepted, command, positive_int, sha, write_json
from suite_contract import (SHARDS, audit_report, benchmark_rows, build_argv, check_module_names,
                            driver_source, fold_runs, inventory, judge, parse_run, run_argv)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    add_library_arguments(parser)
    parser.add_argument('--filter', default='', help='Only programs whose path contains this text')
    parser.add_argument('--output')
    parser.add_argument('--werror', action='store_true')
    parser.add_argument('--optimization', type=int, choices=(0, 3), default=3,
                        help='3 (default) or 0; O0 builds are several times slower and larger')
    parser.add_argument('--jobs', type=positive_int, default=len(SHARDS),
                        help=f'Executables built at once (default: {len(SHARDS)}); each needs up to ~3 GB')
    parser.add_argument('--compile-timeout', type=positive_int, default=1800,
                        help='Seconds per executable build (default: 1800)')
    parser.add_argument('--run-timeout', type=positive_int, default=600,
                        help='Seconds per executable run (default: 600)')
    args = parser.parse_args()
    if problems := check_module_names():
        parser.error('ambiguous module names:\n  ' + '\n  '.join(problems))
    modules = inventory(args.filter)
    if not modules:
        parser.error('No programs selected')
    run = RunContext.start(args.output or f'.cache/suite/{uuid.uuid4().hex}', 'suite')
    include, package = library_include(args, run.folder)
    shards = [(name, [m for m in modules if m['shard'] == name]) for name, _, _ in SHARDS]
    shards = [(name, members) for name, members in shards if members]
    (run.folder / 'drivers').mkdir()
    print(run.host['compiler'], f'- {len(modules)} programs against {include}', flush=True)
    print(f'Building {len(shards)} executables in {run.binaries}', flush=True)

    def build(shard):
        name, members = shard
        driver = run.folder / 'drivers' / f'suite_{name.replace("-", "_")}.mojo'
        driver.write_text(driver_source(name, members))
        executable = run.binaries / f'fp-suite-{name}'
        compiled = command(build_argv(include, name, driver, executable, args.werror, args.optimization),
                           run.folder / 'logs' / f'{name}.build.log', timeout=args.compile_timeout)
        state = f'built in {compiled["seconds"]:.0f} s' if accepted(compiled) else 'FAILED TO BUILD'
        print(f'  {name}: {len(members)} programs, {state}', flush=True)
        if not accepted(compiled):
            print((compiled['stdout'] + compiled['stderr'])[-8000:], flush=True)
        return dict(name=name, driver=str(driver), driver_sha256=sha(driver), compilation=compiled,
                    executable=str(executable), runs=[],
                    executable_sha256=sha(executable) if executable.is_file() else None)

    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        records = list(pool.map(build, shards))

    rows, benchmarks = [], []
    for record, (name, members) in zip(records, shards):
        if accepted(record['compilation']):
            start = 0
            while start is not None and start < len(members):
                result = command(run_argv(record['executable'], start),
                                 run.folder / 'logs' / f'{name}.run{len(record["runs"])}.log',
                                 timeout=args.run_timeout)
                record['runs'].append(result)
                _, stopped, ended = parse_run(result['stdout'])
                start = None if ended or stopped is None else stopped + 1
            outcomes = fold_runs(members, record['runs'])
        else:
            outcomes = [dict(path=m['path'], passed=False, error='not built', output='') for m in members]
        for module, outcome in zip(members, outcomes):
            error = judge(module, outcome)
            rows.append(dict(path=module['path'], shard=name, kind=module['kind'], passed=error is None,
                             error=error, nanoseconds=outcome.get('nanoseconds')))
            if module['kind'] == 'benchmark':
                benchmarks += benchmark_rows(module, outcome)
            if error is not None:
                label = 'BENCHMARK ERROR' if module['kind'] == 'benchmark' else 'FAIL'
                print(f'{label} {module["path"]}: {error}', flush=True)
                if module['kind'] == 'example' and outcome['passed']:
                    print(outcome['output'], flush=True)
        checked = [r for r in rows if r['shard'] == name and r['kind'] != 'benchmark']
        seconds = sum(r['nanoseconds'] or 0 for r in checked) / 1e9
        print(f'{name}: {sum(r["passed"] for r in checked)}/{len(checked)} passed '
              f'({seconds:.2f} s in programs)', flush=True)

    if benchmarks:
        print(f'Benchmarks (diagnostic; O{args.optimization}, median of each program\'s samples):')
        for b in benchmarks:
            print(f'  {b["name"]:<16} native {b["native_ns"] / 1e6:8.2f} ms   '
                  f'library {b["library_ns"] / 1e6:8.2f} ms   {b["ratio"]:.2f}x')
    checked = [r for r in rows if r['kind'] != 'benchmark']
    report = dict(**run.metadata(), include=include, package_compilation=package, filter=args.filter,
                  werror=args.werror, optimization=args.optimization, jobs=args.jobs,
                  compile_timeout=args.compile_timeout, run_timeout=args.run_timeout,
                  shards=records, modules=rows, benchmarks=benchmarks,
                  passed=all(r['passed'] for r in checked))
    audit = audit_report(report, folder=run.folder, include=include, filter=args.filter,
                         werror=args.werror, optimization=args.optimization, expected_inputs=run.before)
    report['audit_failures'] = audit
    write_json(run.folder / 'report.json', report)
    failures = sum(not r['passed'] for r in checked)
    print(f'{len(checked) - failures}/{len(checked)} passed; {len(audit)} audit failures; '
          f'report {run.folder / "report.json"}')
    for failure in audit:
        print('AUDIT', failure)
    return bool(failures or audit)


if __name__ == '__main__':
    sys.exit(main())
