"""Bounded async soak, retained storage, and separate serial performance diagnostics.

Run in an immutable checkout with the pinned toolchain. The default twelve
one-hour soaks use at most two workers (six hours plus compilation). Short
calibrations are supported but never reported as overnight qualification.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict
import json
from pathlib import Path
import shutil
import sys
import time

EXPERIMENT = Path(__file__).resolve().parent
ROOT = EXPERIMENT.parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from fp_tools.artifacts import manifest, audit as audit_artifacts
from fp_tools.cases import CompileCase, audit_case, execute_case
from fp_tools.library import precompile
from fp_tools.runs import RunContext, audit_run_paths
from fp_tools.runtime import (accepted, audit_command, command, inputs, normalized,
                              positive_int, resolved, sha, timed_argv, write_json)
from stress_contract import (CLIENTS, ROUTES, LEVELS, MEMORY_BYTES, MINIMUM_CYCLES,
                             RSS_INTERVAL, stress_observation, memory_observation,
                             performance_observation)


def experiment_inputs():
    return {str(p.relative_to(ROOT)): sha(p) for p in sorted(EXPERIMENT.rglob("*"))
            if p.is_file() and "__pycache__" not in p.parts}


def specifications(folder):
    for name in (*CLIENTS, "performance"):
        for route in ROUTES:
            for level in ((3,) if name == "performance" else LEVELS):
                identity = f"{name}-{route}-O{level}"
                case = CompileCase.from_source(
                    str((EXPERIMENT / "stress" / f"{name}.mojo").relative_to(ROOT)), level,
                    include=str(folder / route), werror=True, compiler_threads=1,
                    compile_timeout=900, execution_timeout=120,
                    memory_limit_bytes=4 * 1024**3,
                    execution_memory_limit_bytes=MEMORY_BYTES)
                yield identity, name, route, case


def execution_audit(record, binary, folder, arguments):
    if not accepted(record) or not audit_command(record):
        raise ValueError("failed execution or raw evidence")
    expected = timed_argv([binary, *arguments])
    if ([normalized(x) for x in record["command"]] != [normalized(x) for x in expected]
            or record.get("memory_limit_bytes") != MEMORY_BYTES):
        raise ValueError("wrong execution or memory policy")
    for key in ("log", "rss_samples_log"):
        if not resolved(record[key]).resolve().is_relative_to(folder):
            raise ValueError("execution evidence outside run")
    if record.get("rss_interval_seconds") != RSS_INTERVAL:
        raise ValueError("wrong RSS sampling policy")


def audit_selected_inputs(folder):
    for original, retained in ((ROOT / "src/fp", folder / "source/fp"),
                               (EXPERIMENT / "state_machine", folder / "source/state_machine")):
        def contents(directory):
            return {str(p.relative_to(directory)): sha(p) for p in directory.rglob("*")
                    if p.is_file() and "__pycache__" not in p.parts}
        if contents(original) != contents(retained):
            raise ValueError("selected source differs from frozen library")
    helpers = {p.name: sha(p) for p in (EXPERIMENT / "tests").glob("*.mojo")}
    for route in ROUTES:
        if {p.name: sha(p) for p in (folder / route).glob("*.mojo")} != helpers:
            raise ValueError("selected fixture helper differs from frozen source")
    if {p.name for p in (folder / "package").iterdir()} != set(helpers) | {"fp.mojoc", "state_machine.mojoc"}:
        raise ValueError("package route has missing packages or source fallback")


def audit_report(report, folder):
    failures = []
    try:
        binaries = audit_run_paths(report, folder)
        seconds, minimum = report["seconds_per_case"], report["minimum_cycles"]
        if type(seconds) is not int or not 1 <= seconds <= 86400 or type(minimum) is not int or minimum < MINIMUM_CYCLES:
            raise ValueError("invalid run budgets")
        if (report["inputs"] != inputs() or report["experiment_inputs"] != experiment_inputs()
                or report.get("inputs_unchanged") is not True
                or report.get("experiment_unchanged") is not True):
            raise ValueError("changed immutable qualification inputs")
        audit_selected_inputs(folder)
        builds = report["package_compilations"]
        if len(builds) != 2:
            raise ValueError("missing packages")
        for name, include, record in zip(("fp", "state_machine"),
                                         (folder / "source", folder / "package"), builds):
            expected = ["mojo", "precompile", "-I", include, "--Werror", folder / "source" / name,
                        "-o", folder / "package" / f"{name}.mojoc"]
            if (not accepted(record) or not audit_command(record)
                    or [normalized(x) for x in record["command"]] != [normalized(x) for x in expected]):
                raise ValueError("package compilation evidence")
        specifications_by_id = {identity: (name, case) for identity, name, _, case in specifications(folder)}
        records = report["compilations"]
        if set(records) != set(specifications_by_id):
            raise ValueError("incomplete compilation matrix")
        for identity, (name, case) in specifications_by_id.items():
            record = records[identity]
            errors = audit_case(case, record, binaries / identity, folder=folder)
            if errors:
                raise ValueError(identity + ": " + "; ".join(errors))
            if name == "performance":
                performance_observation(record["execution"]["stdout"])
            else:
                stress_observation(name, record["execution"]["stdout"], 0, MINIMUM_CYCLES)
        expected_soaks = {key for key, (name, _) in specifications_by_id.items() if name != "performance"}
        if set(report["soaks"]) != expected_soaks:
            raise ValueError("incomplete soak matrix")
        for identity, record in report["soaks"].items():
            execution_audit(record, binaries / identity, folder, [str(seconds), str(minimum)])
            name = specifications_by_id[identity][0]
            stress_observation(name, record["stdout"], seconds, minimum)
            memory_observation(resolved(record["rss_samples_log"]).read_text(), seconds)
        if set(report["performance"]) != set(specifications_by_id) - expected_soaks:
            raise ValueError("incomplete performance matrix")
        for identity, record in report["performance"].items():
            execution_audit(record, binaries / identity, folder, [])
            performance_observation(record["stdout"])
        failures += audit_artifacts(report, folder)
    except (ValueError, KeyError, TypeError, OSError, AttributeError, IndexError) as error:
        failures.append(str(error))
    return failures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--output", help="Fresh retained run directory within the checkout")
    modes.add_argument("--audit", help="Recheck a finished bundle without running the toolchain")
    parser.add_argument("--seconds", type=positive_int, default=3600)
    parser.add_argument("--minimum-cycles", type=positive_int, default=10000)
    parser.add_argument("--jobs", type=positive_int, default=2)
    args = parser.parse_args()
    if Path.cwd().resolve() != ROOT:
        parser.error("Run from the immutable repository root")
    if args.audit:
        folder = (ROOT / args.audit).resolve()
        errors = audit_report(json.loads((folder / "report.json").read_text()), folder)
        print("PASS" if not errors else "FAIL", errors)
        return bool(errors)
    if args.jobs > 2 or args.seconds > 86400 or not MINIMUM_CYCLES <= args.minimum_cycles <= 1000000000:
        parser.error("At most two workers, 86400 seconds, and 64..1000000000 cycles")
    run = RunContext.start(args.output, "async-stress")
    before = experiment_inputs()
    started = time.time()
    base = dict(seconds_per_case=args.seconds, minimum_cycles=args.minimum_cycles,
                jobs=args.jobs, started_unix=started, experiment_inputs=before,
                performance_profile="local Linux diagnostic, serial after soaks; no throughput SLO")
    write_json(run.folder / "started.json", dict(**run.metadata(), **base))
    write_json(run.folder / "status.json", dict(phase="preparing", **base))
    for route in ROUTES:
        (run.folder / route).mkdir()
        for path in (EXPERIMENT / "tests").glob("*.mojo"):
            shutil.copy2(path, run.folder / route / path.name)
    shutil.copytree(ROOT / "src/fp", run.folder / "source/fp", symlinks=True)
    shutil.copytree(EXPERIMENT / "state_machine", run.folder / "source/state_machine", symlinks=True)
    builds, compilations, soaks, performance, observations = [], {}, {}, {}, {}
    error = None
    try:
        for name, include in (("fp", run.folder / "source"), ("state_machine", run.folder / "package")):
            record = precompile(run.folder / "package" / f"{name}.mojoc", run.folder / f"{name}.log",
                                source=str(run.folder / "source" / name), include=str(include), timeout=180,
                                memory_limit_bytes=4 * 1024**3)
            builds.append(record)
            write_json(run.folder / "package-compilations.json", builds)
            if not accepted(record):
                raise ValueError("package precompilation failed: " + name)
        jobs = list(specifications(run.folder))
        write_json(run.folder / "status.json", dict(phase="compiling", started_unix=started))

        def compile_client(job):
            identity, name, _, case = job
            binary = run.binaries / identity
            result = execute_case(case, binary, run.folder / "cases" / identity)
            errors = audit_case(case, result, binary, folder=run.folder)
            try:
                if errors:
                    raise ValueError("; ".join(errors))
                if name == "performance":
                    performance_observation(result["execution"]["stdout"])
                else:
                    stress_observation(name, result["execution"]["stdout"], 0, MINIMUM_CYCLES)
            except (ValueError, TypeError, KeyError, IndexError) as exc:
                errors.append(str(exc))
            result.update(specification=asdict(case), audit_failures=errors)
            write_json(run.folder / "cases" / f"{identity}.json", result)
            print("COMPILE", identity, "PASS" if result["passed"] and not errors else "FAIL", flush=True)
            return identity, result

        with ThreadPoolExecutor(max_workers=args.jobs) as pool:
            compilations = dict(pool.map(compile_client, jobs))
        if any(not r["passed"] or r["audit_failures"] for r in compilations.values()):
            raise ValueError("compilation/smoke failed; overnight work was not started")
        write_json(run.folder / "status.json", dict(phase="soaking", started_unix=started, soak_started_unix=time.time()))

        def soak(job):
            identity, name, _, _ = job
            result = command([run.binaries / identity, str(args.seconds), str(args.minimum_cycles)],
                             run.folder / "soaks" / f"{identity}.log", timeout=args.seconds + 300,
                             timed=True, memory_limit_bytes=MEMORY_BYTES,
                             rss_samples_log=run.folder / "soaks" / f"{identity}.rss.jsonl")
            write_json(run.folder / "soaks" / f"{identity}.json", result)
            print("SOAK", identity, "EXIT", result["exit_code"], flush=True)
            return identity, result

        with ThreadPoolExecutor(max_workers=args.jobs) as pool:
            soaks = dict(pool.map(soak, [j for j in jobs if j[1] != "performance"]))
        # All stress workers have joined before collecting performance samples.
        write_json(run.folder / "status.json", dict(phase="measuring", started_unix=started))
        for identity, name, _, _ in jobs:
            if name == "performance":
                result = command([run.binaries / identity], run.folder / "performance" / f"{identity}.log",
                                 timeout=120, timed=True, memory_limit_bytes=MEMORY_BYTES,
                                 rss_samples_log=run.folder / "performance" / f"{identity}.rss.jsonl")
                performance[identity] = result
                write_json(run.folder / "performance" / f"{identity}.json", result)
        for identity, record in soaks.items():
            name = identity.split("-")[0]
            observations[identity] = dict(
                work=stress_observation(name, record["stdout"], args.seconds, args.minimum_cycles),
                memory=memory_observation(resolved(record["rss_samples_log"]).read_text(), args.seconds))
        for identity, record in performance.items():
            observations[identity] = performance_observation(record["stdout"])
    except Exception as exc:
        error = f"{type(exc).__name__}: {exc}"
    write_json(run.folder / "status.json", dict(phase="finished", started_unix=started, finished_unix=time.time(), error=error))
    report = dict(**run.metadata(), **base, experiment_unchanged=before == experiment_inputs(),
                  package_compilations=builds, compilations=compilations, soaks=soaks,
                  performance=performance, observations=observations, error=error,
                  elapsed_seconds=time.time() - started, artifact_sha256=manifest(run.folder))
    errors = audit_report(report, run.folder)
    if error:
        errors.append(error)
    passed = not errors
    report.update(passed=passed, audit_failures=errors, overnight_qualified=passed and args.seconds >= 3600)
    write_json(run.folder / "report.json", report)
    print("PASS" if passed else "FAIL", "overnight_qualified=" + str(report["overnight_qualified"]), errors, flush=True)
    return not passed


if __name__ == "__main__":
    sys.exit(main())
