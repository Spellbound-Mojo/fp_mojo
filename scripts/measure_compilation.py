"""Small, serial compilation observations using the shared execution contracts.

Every build uses its own empty Mojo cache: a warm cache hides most of the cost.
Resource observations on Linux do not qualify the historical macOS benchmarks.
Stop at the first failure.
"""
import argparse
from dataclasses import asdict
from pathlib import Path
import re
import uuid

from fp_tools.cases import CompileCase, audit_case, execute_case
from fp_tools.artifacts import library_inputs
from fp_tools.runtime import (ROOT, binary_directory, environment, input_changes,
                              inputs, positive_int, reserve_output, write_json)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('sources', nargs='+')
    parser.add_argument('--level', type=int, choices=(0, 3), default=3)
    parser.add_argument('--include', default='src')
    parser.add_argument('--threads', type=positive_int, default=2)
    parser.add_argument('--timeout', type=positive_int, default=180)
    parser.add_argument('--memory-mib', type=positive_int, default=4096)
    parser.add_argument('--output')
    args = parser.parse_args()
    if args.timeout > 180 or args.memory_mib > 4096 or args.threads > 2:
        parser.error('This focused profile is capped at 180 seconds, 4096 MiB and two compiler threads')
    folder = reserve_output(args.output or f'.cache/compilation/{uuid.uuid4().hex}')
    binaries = binary_directory(folder, 'clients')
    before = inputs()
    library_before = library_inputs(args.include)
    report = dict(host=environment(), records=[], inputs=before, passed=True,
                  library_inputs=library_before)
    for index, source in enumerate(args.sources):
        path = ROOT/source
        rejected = (tuple(re.findall(r'^# error: (.+)$', path.read_text(), re.M))
                    if path.resolve().parent.name == 'compile_fail' else None)
        case = CompileCase.from_source(source, args.level, include=args.include,
                                       compiler_threads=args.threads, measured=True, cold_cache=True,
                                       werror=True,
                                       reject=rejected,
                                       compile_timeout=args.timeout,
                                       memory_limit_bytes=args.memory_mib*1024*1024)
        binary = binaries/f'{index}-{Path(source).stem}'
        result = execute_case(case, binary, folder/f'{index}-{Path(source).stem}')
        failures = audit_case(case, result, binary, folder=folder)
        row = dict(specification=asdict(case), **result, audit_failures=failures,
                   file_bytes=binary.stat().st_size if binary.is_file() else None)
        compiled = result['compilation']
        report['records'].append(row)
        print(f'{source} O{args.level}: {compiled["seconds"]:.2f}s cold '
              f'RSS={compiled["peak_rss_bytes"]} passed={result["passed"] and not failures}', flush=True)
        report['input_changes'] = input_changes(before, inputs())
        report['library_changes'] = input_changes(library_before, library_inputs(args.include))
        report['passed'] &= (result['passed'] and not failures
                             and not report['input_changes'] and not report['library_changes'])
        write_json(folder/'report.json', report)
        if not report['passed']:
            print('; '.join(failures) + '\n' + (compiled['stdout'] + compiled['stderr'])[:6000], flush=True)
            break
    print(folder/'report.json')
    return not report['passed']


if __name__ == '__main__':
    raise SystemExit(main())
