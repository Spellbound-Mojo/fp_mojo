"""Qualify native admission against source and fresh bytecode at O0 and O3.

The normal suite and rejection runner also discover these maintained fixtures.
This gate checks their import/optimization matrix independently. Native compiler
crashes, timeouts and unexpectedly accepted negatives never count as passes.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict
from pathlib import Path
import re

from fp_tools.artifacts import library_inputs
from fp_tools.cases import CompileCase, audit_case, execute_case
from fp_tools.library import precompile
from fp_tools.runs import RunContext
from fp_tools.runtime import ROOT, accepted, positive_int, write_json


def inventory(filter_=""):
    paths = []
    for folder in ("runtime", "ownership", "compile_fail"):
        for path in sorted((ROOT / "tests" / folder).glob("*.mojo")):
            stem = path.stem.removeprefix("test_")
            if not stem.startswith(("capture_", "context_")) or filter_ not in stem:
                continue
            errors = tuple(re.findall(r"^# error: (.+)$", path.read_text(), re.M))
            if bool(errors) != (folder == "compile_fail"):
                raise ValueError(f"Fixture diagnostics disagree with directory: {path}")
            paths.append((str(path.relative_to(ROOT)), errors))
    return paths


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True)
    parser.add_argument("--jobs", type=positive_int, default=3)
    parser.add_argument("--filter", default="")
    args = parser.parse_args()
    clients = inventory(args.filter)
    if not clients:
        parser.error("No boundary fixtures selected")
    run = RunContext.start(args.output, "native-admission")
    package = run.folder / "package"
    package.mkdir()
    built = precompile(
        package / "fp.mojoc", run.folder / "package.log", include="src", source="src/fp"
    )
    if not accepted(built):
        raise SystemExit("Package precompilation failed; see package.log")
    packaged = library_inputs(package)
    jobs = []
    for path, errors in clients:
        for route, include in (("source", "src"), ("package", str(package))):
            for level in (0, 3):
                case = CompileCase.from_source(
                    path,
                    level,
                    include=include,
                    reject=errors or None,
                    compiler_threads=1,
                    werror=True,
                    compile_timeout=180,
                    execution_timeout=30,
                )
                jobs.append((route, case))
    print(f"{len(clients)} clients, {len(jobs)} checks", flush=True)

    def check(job):
        route, case = job
        name = f"{Path(case.source).stem}-{route}-O{case.optimization}"
        binary = run.binaries / name
        result = execute_case(case, binary, run.folder / "cases" / name)
        failures = audit_case(case, result, binary, folder=run.folder)
        print("PASS" if result["passed"] and not failures else "FAIL", name, flush=True)
        return dict(route=route, specification=asdict(case), **result, audit_failures=failures)

    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        records = list(pool.map(check, jobs))
    metadata = run.metadata()
    unchanged = packaged == library_inputs(package)
    passed = (
        metadata["inputs_unchanged"]
        and unchanged
        and all(r["passed"] and not r["audit_failures"] for r in records)
    )
    write_json(
        run.folder / "report.json",
        dict(
            **metadata,
            declared_inventory=clients,
            package_compilation=built,
            package_inputs=packaged,
            package_unchanged=unchanged,
            records=records,
            passed=passed,
        ),
    )
    print(
        f"{sum(r['passed'] and not r['audit_failures'] for r in records)}/{len(records)} checks; passed={passed}"
    )
    return not passed


if __name__ == "__main__":
    raise SystemExit(main())
