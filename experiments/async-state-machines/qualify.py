"""Qualify the private machine protocol using the canonical repository runner.

Run from the repository root in its pinned Mojo environment. Each invocation
requires a fresh output directory and retains diagnostics, hashes and binaries.
"""
import argparse
import hashlib
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict
from pathlib import Path
import re
import shutil
import sys

EXPERIMENT = Path(__file__).resolve().parent
ROOT = EXPERIMENT.parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from fp_tools.artifacts import manifest
from fp_tools.cases import CompileCase, audit_case, execute_case
from fp_tools.library import precompile
from fp_tools.runs import RunContext
from fp_tools.runtime import accepted, audit_command, command, positive_int, sha, write_json

POSITIVE = {"foundation", "composition", "loop_lifecycle", "children", "origins", "wakes", "depth", "callbacks", "callback_origins", "nurseries", "nursery_origins", "scheduler", "async_coordination", "coordination_owned", "coordination_origins", "racing", "racing_origins", "timeouts", "workload", "async_finalization", "async_masking", "finalization_origins"}
REGRESSIONS = (
    "tests/runtime/test_io_finalization.mojo",
    "tests/runtime/test_resource_scopes.mojo",
    "tests/runtime/test_io_resources.mojo",
    "tests/ownership/test_io_finalization_owned.mojo",
    "tests/ownership/test_io_resources_owned.mojo",
    "tests/runtime/test_coordination.mojo",
    "tests/ownership/test_coordination_owned.mojo",
    "tests/runtime/test_io_effects.mojo",
    "tests/runtime/test_fibers.mojo",
)
POSITIVE.add("checkpoints")
POSITIVE.add("selection_policies")


def experiment_inputs():
    return {str(p.relative_to(ROOT)): sha(p)
            for p in sorted(EXPERIMENT.rglob("*"))
            if p.is_file() and "__pycache__" not in p.parts}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True)
    parser.add_argument("--jobs", type=positive_int, default=2)
    parser.add_argument("--client", action="append", default=[], help="Qualify only the named client stem; repeat to select several")
    args = parser.parse_args()
    if Path.cwd().resolve() != ROOT:
        parser.error("Run from the repository root")
    clients = sorted((EXPERIMENT / "tests").glob("*.mojo"))
    clients += [ROOT / path for path in REGRESSIONS]
    known = {p.stem for p in clients}
    if set(args.client) - known:
        parser.error("Unknown clients: " + ", ".join(sorted(set(args.client) - known)))
    if {p.stem for p in clients if p.stem in POSITIVE} != POSITIVE:
        raise SystemExit("Missing declared positive client")
    selected = sorted(set(args.client)) or None
    if selected:
        clients = [p for p in clients if p.stem in selected]
    run = RunContext.start(args.output, "state-machines")
    before = experiment_inputs()
    source = run.folder / "source"
    shutil.copytree(ROOT / "src/fp", source / "fp")
    shutil.copytree(EXPERIMENT / "state_machine", source / "state_machine")
    shutil.copytree(EXPERIMENT / "tests", run.folder / "test-snapshot")
    package = run.folder / "package"
    package.mkdir()
    builds = []
    for name, include in (("fp", source), ("state_machine", package)):
        built = precompile(package / f"{name}.mojoc", run.folder / f"{name}.log",
                           source=str(source / name), include=str(include), timeout=120)
        builds.append(built)
        if not accepted(built):
            write_json(run.folder / "report.json", dict(
                **run.metadata(), experiment_inputs=before, selected_clients=selected, package_compilations=builds,
                passed=False))
            raise SystemExit(f"Precompilation failed: inspect {name}.log")

    jobs = []
    for client in clients:
        errors = tuple(re.findall(r"^# error: (.+)$", client.read_text(), re.M))
        regression = str(client.relative_to(ROOT)) in REGRESSIONS
        if not regression and client.stem not in POSITIVE and not errors:
            raise SystemExit(f"Undeclared test kind: {client.name}")
        expected = None if errors else "" if regression else client.with_suffix(".stdout").read_text()
        for route, include in (("source", source), ("package", package)):
            for level in (0, 3):
                case = CompileCase.from_source(
                    str(client.relative_to(ROOT)), level, include=str(include),
                    reject=errors or None, expected_stdout=expected,
                    werror=True, compiler_threads=1, compile_timeout={"depth": 360, "racing_origins": 240, "timeouts": 240, "selection_policies": 240, "workload": 360}.get(client.stem, 120),
                    execution_timeout=90 if client.stem == "composition" else 15)
                jobs.append((route, case))

    def check(job):
        route, case = job
        name = f"{Path(case.source).stem}-{route}-O{case.optimization}"
        binary = run.binaries / name
        result = execute_case(case, binary, run.folder / "cases" / name)
        audit = audit_case(case, result, binary, folder=run.folder)
        bounded_stack = None
        if result["passed"] and not audit and Path(case.source).stem in {"composition", "loop_lifecycle", "depth"}:
            # Apply the stack limit to execution only, never to the compiler.
            bounded_stack = command(
                ["bash", "-c", 'ulimit -s 1024\nexec "$1"', "bounded-stack", str(binary)],
                run.folder / "cases" / f"{name}.stack.log", timeout=case.execution_timeout)
            if not (accepted(bounded_stack) and audit_command(bounded_stack)
                    and hashlib.sha256(bounded_stack["stdout"].encode()).hexdigest() == case.stdout_sha256):
                audit.append("execution with 1024 KiB stack failed")
        print("PASS" if result["passed"] and not audit else "FAIL", name, flush=True)
        return dict(route=route, specification=asdict(case), **result, audit_failures=audit,
                    bounded_stack=bounded_stack, stack_limit_kib=1024 if bounded_stack else None)

    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        records = list(pool.map(check, jobs))
    metadata = run.metadata()
    unchanged = before == experiment_inputs()
    passed = (metadata["inputs_unchanged"] and unchanged
              and all(r["passed"] and not r["audit_failures"] for r in records))
    write_json(run.folder / "report.json", dict(
        **metadata, experiment_inputs=before, experiment_unchanged=unchanged, selected_clients=selected,
        package_compilations=builds, records=records, passed=passed,
        artifact_sha256=manifest(run.folder)))
    print(f"{sum(r['passed'] and not r['audit_failures'] for r in records)}/{len(records)} checks; passed={passed}")
    return not passed


if __name__ == "__main__":
    sys.exit(main())
