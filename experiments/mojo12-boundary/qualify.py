"""Qualify the isolated Mojo 1.2 boundary prototype using the repository runner.

The overlay and package are created only in a fresh output directory. Production
sources are read, never changed. Failed or unexpectedly accepted rejections are
never executed; the canonical execution/audit helpers enforce that policy.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict
import json
from pathlib import Path
import re
import shutil
import sys

EXPERIMENT = Path(__file__).resolve().parent
ROOT = EXPERIMENT.parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from fp_tools.artifacts import library_inputs
from fp_tools.cases import CompileCase, audit_case, execute_case
from fp_tools.library import precompile
from fp_tools.runs import RunContext
from fp_tools.runtime import accepted, positive_int, sha, write_json


def experiment_inputs():
    return {str(p.relative_to(ROOT)): sha(p)
            for p in sorted(EXPERIMENT.rglob("*"))
            if p.is_file() and "__pycache__" not in p.parts}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True)
    parser.add_argument("--jobs", type=positive_int, default=3)
    profiles = parser.add_mutually_exclusive_group()
    profiles.add_argument("--bindings", action="store_true",
                          help="Run the unqualified argument-binding experiment")
    profiles.add_argument("--receivers", action="store_true",
                          help="Reproduce the failed owned/native receiver controls")
    profiles.add_argument("--invocation", action="store_true",
                          help="Check explicit state and staged keyword admission")
    profiles.add_argument("--arguments", action="store_true",
                          help="Check argument-inferred keywords and the invocation baseline")
    args = parser.parse_args()
    if Path.cwd().resolve() != ROOT:
        parser.error("Run from the repository root")
    run = RunContext.start(args.output, "native-boundary")
    before = experiment_inputs()
    library = run.folder / "library"
    shutil.copytree(ROOT / "src/fp", library / "fp")
    shutil.copyfile(EXPERIMENT / "native_boundary.mojo", library / "fp/_architecture.mojo")
    invocation = args.invocation or args.arguments
    if args.bindings or args.receivers or invocation:
        shutil.copyfile(EXPERIMENT / "binding_boundary.mojo",
                        library / "fp/_binding_architecture.mojo")
    if args.receivers:
        shutil.copyfile(EXPERIMENT / "owned_boundary.mojo",
                        library / "fp/_binding_owned.mojo")
    if invocation:
        for source, module in (("stateful_boundary", "_binding_state"),
                               ("keyword_boundary", "_binding_staged")):
            shutil.copyfile(EXPERIMENT / f"{source}.mojo", library / f"fp/{module}.mojo")
    if args.arguments:
        shutil.copyfile(EXPERIMENT / "argument_boundary.mojo",
                        library / "fp/_argument_staged.mojo")
    # Native invocation fixes are now owned by the production library.
    prototype = library_inputs(library)
    package = run.folder / "package"
    package.mkdir()
    built = precompile(package / "fp.mojoc", run.folder / "package.log",
                       include=str(library), source=str(library / "fp"))
    if not accepted(built):
        raise SystemExit("Prototype precompilation failed; inspect package.log")
    inventory = ("arguments.json" if args.arguments else "invocation.json" if args.invocation else "receivers.json" if args.receivers
                 else "bindings.json" if args.bindings else "clients.json")
    inventories = ["invocation.json", inventory] if args.arguments else [inventory]
    clients = [client for name in inventories
               for client in json.loads((EXPERIMENT / name).read_text())]
    paths = [item["source"] for item in clients]
    if len(paths) != len(set(paths)) or not paths:
        raise SystemExit("Empty or duplicate client inventory")
    jobs = []
    for item in clients:
        source = (EXPERIMENT / item["source"]).resolve()
        if not source.is_relative_to(EXPERIMENT / "clients"):
            raise SystemExit("Client must be within the experiment's clients directory")
        if item["kind"] not in ("positive", "rejection"):
            raise SystemExit("Unknown client kind")
        errors = tuple(re.findall(r"^# error: (.+)$", source.read_text(), re.M))
        if bool(errors) != (item["kind"] == "rejection"):
            raise SystemExit("Client diagnostics disagree with its declared kind")
        for route, include in (("source", library), ("package", package)):
            for level in (0, 3):
                case = CompileCase.from_source(
                    str(source.relative_to(ROOT)), level, include=str(include),
                    reject=errors or None, werror=True, compiler_threads=1,
                    compile_timeout=120, execution_timeout=30)
                jobs.append((item["kind"], route, case))

    def check(job):
        kind, route, case = job
        name = f"{Path(case.source).stem}-{route}-O{case.optimization}"
        binary = run.binaries / name
        result = execute_case(case, binary, run.folder / "cases" / name)
        audit = audit_case(case, result, binary, folder=run.folder)
        print("PASS" if result["passed"] and not audit else "FAIL", name, flush=True)
        return dict(kind=kind, route=route, specification=asdict(case),
                    **result, audit_failures=audit)

    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        records = list(pool.map(check, jobs))
    metadata = run.metadata()
    unchanged = before == experiment_inputs() and prototype == library_inputs(library)
    passed = (metadata["inputs_unchanged"] and unchanged and
              all(r["passed"] and not r["audit_failures"] for r in records))
    write_json(run.folder / "report.json", dict(
        **metadata, experiment_inputs=before, prototype_inputs=prototype,
        inventory=inventory, included_inventories=inventories,
        prototype_unchanged=unchanged, package_compilation=built,
        declared_inventory=clients, records=records, passed=passed))
    print(f"{sum(r['passed'] for r in records)}/{len(records)} checks; passed={passed}")
    return not passed


if __name__ == "__main__":
    sys.exit(main())
