"""Independent audit of compile-failure runs: flags are conclusions, not evidence."""
import re
from fp_tools.runtime import ROOT, PIN, sha, normalized
from fp_tools.cases import CompileCase, audit_case
from fp_tools.runs import audit_run_paths

def inventory(filter='', root=ROOT):
    paths = sorted((root/'tests/compile_fail').glob('*.mojo'))
    return [str(p.relative_to(root)) for p in paths if filter in str(p.relative_to(root))]


def audit_report(report, *, folder, optimization, include, filter='', werror=False, expected_inputs, root=ROOT):
    failures = []
    expected = inventory(filter, root)
    try:
        timeout = report.get('compile_timeout', 180)
        if type(timeout) is not int or timeout <= 0:
            raise ValueError('invalid compilation timeout')
        records = report.get('tests', [])
        paths = [r.get('path') for r in records]
        if not expected or len(paths) != len(expected) or set(paths) != set(expected):
            failures.append('missing/duplicate/unexpected fixture inventory')
        if report.get('declared_inventory') != expected:
            failures.append('declared fixture inventory')
        if (report.get('compiler') != PIN or report.get('optimization') != str(optimization)
                or normalized(report.get('include'), root) != normalized(include, root)
                or report.get('filter') != filter or report.get('werror') is not werror):
            failures.append('compiler/optimization/import/filter/warning policy')
        if (not expected_inputs or report.get('inputs') != expected_inputs
                or report.get('input_changes') != [] or report.get('inputs_unchanged') is not True):
            failures.append('stale/changed input binding')
        binaries = audit_run_paths(report, folder, root)
        for row in records:
            path = row.get('path')
            if path not in expected:
                continue
            source = root / path
            errors = tuple(re.findall(r'^# error: (.+)$', source.read_text(), re.M))
            case = CompileCase.from_source(path, int(optimization), root=root,
                                           include=str(include), werror=werror, reject=errors,
                                           compile_timeout=timeout)
            if row.get('sha256') != case.source_sha256 or row.get('expected_errors') != (list(errors) if errors else None):
                failures.append(f'{path}: source hash/expected diagnostic changed')
            artifact = binaries / path.replace('/', '_').removesuffix('.mojo')
            if [normalized(v,root) for v in row.get('command',[])] != [normalized(v,root) for v in case.argv(artifact)]:
                failures.append(f'{path}: declared invocation')
            failures += [f'{path}: {error}' for error in audit_case(case, row, artifact, root=root, folder=folder)]
            if row.get('passed') is not True:
                failures.append(f'{path}: contradictory child conclusion')
    except (ValueError, KeyError, TypeError, OSError, AttributeError) as error:
        failures.append(str(error))
    return failures
