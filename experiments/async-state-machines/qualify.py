"""Qualify the private machine protocol using the canonical repository runner.

Run from the repository root in its pinned Mojo environment. Each invocation
requires a fresh output directory and retains diagnostics, hashes and binaries.
"""
import argparse
import hashlib
import json
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict
from pathlib import Path
import re
import shutil
import sys

EXPERIMENT = Path(__file__).resolve().parent
ROOT = EXPERIMENT.parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from suite_contract import inventory as suite_inventory
from fp_tools.artifacts import manifest, audit as audit_artifacts
from fp_tools.cases import CompileCase, audit_case, execute_case
from fp_tools.evidence import run_inputs
from fp_tools.library import precompile
from fp_tools.runs import RunContext, audit_run_paths
from fp_tools.runtime import accepted, audit_command, command, inputs, normalized, positive_int, sha, write_json

POSITIVE = {"foundation", "composition", "loop_lifecycle", "children", "origins", "wakes", "depth", "callbacks", "callback_origins", "scheduler", "async_coordination", "coordination_owned", "coordination_origins", "racing", "racing_origins", "timeouts", "workload", "async_finalization", "async_masking", "finalization_origins"}
REGRESSIONS = (
    "tests/runtime/test_context_error_capability.mojo",
    "tests/runtime/test_context_error_mapping_policy.mojo",
    "tests/runtime/test_context_family_attempt_tap_generic.mojo",
    "tests/runtime/test_context_family_conditional_generic.mojo",
    "tests/runtime/test_context_family_ensure_native.mojo",
    "tests/runtime/test_context_family_observation_native.mojo",
    "tests/runtime/test_context_layer_error_mapping.mojo",
    "tests/compile_fail/context_recovery_only_recover.mojo",
    "tests/compile_fail/context_recovery_only_map_err.mojo",
    "tests/compile_fail/context_recovery_only_attempt_tap.mojo",
    "tests/runtime/test_context_error_mapping_native.mojo",
    "tests/runtime/test_context_family_outcome_generic.mojo",
    "tests/runtime/test_context_attempt.mojo",
    "tests/runtime/test_context_recovery_only.mojo",
    "tests/ownership/test_context_attempt_owned.mojo",
    "tests/compile_fail/context_attempt_capability.mojo",
    "tests/compile_fail/context_recovery_only_error.mojo",
    "tests/runtime/test_io_finalization.mojo",
    "tests/runtime/test_resource_scopes.mojo",
    "tests/runtime/test_io_resources.mojo",
    "tests/ownership/test_io_finalization_owned.mojo",
    "tests/ownership/test_io_resources_owned.mojo",
    "tests/runtime/test_coordination.mojo",
    "tests/ownership/test_coordination_owned.mojo",
    "tests/runtime/test_io_effects.mojo",
    "tests/runtime/test_fibers.mojo",
    "tests/runtime/test_context_family_recovery_native.mojo",
    "tests/runtime/test_applicative_error_lifting.mojo",
    "tests/ownership/test_applicative_error_ownership.mojo",
)
REGRESSION_STDOUT = {
    "test_context_attempt": "Pipeline recovery: generic materialization, deferred layer, native selected and intrinsic handlers\n",
    "test_context_attempt_owned": "Pipeline attempt: move-only successes and failures, exact external origins, one destruction\n",
    "test_context_recovery_only": "Pipeline recovery: selected family owns native construction errors without ApplicativeError\n",
    "test_applicative_error_lifting": "applicative error lifting: ok\n",
    "test_applicative_error_ownership": "applicative error ownership: ok\n",
}
POSITIVE.update({"resource_composition", "resource_lifecycle", "resource_owned", "resource_release_factory"})
POSITIVE.update({"pipeline_attempt", "pipeline_recovery_native"})
POSITIVE.add("coordination_family")
POSITIVE.add("io_native_errors")
POSITIVE.update({"host_admission", "extension_boundary", "duration_admission", "instant_clock", "instant_timers", "instant_cleanup"})
PUBLIC_EXAMPLES = {"async_sequencing", "async_iteration", "async_resources", "async_error_recovery", "async_callback_timeout", "async_host_cancel", "async_test_control"}
for example in suite_inventory():
    if example["kind"] == "example" and Path(example["path"]).stem in PUBLIC_EXAMPLES:
        REGRESSIONS += (example["path"],)
        REGRESSION_STDOUT[Path(example["path"]).stem] = example["stdout"]
POSITIVE.update({"public_generic", "public_resources", "public_owned", "public_extension", "public_traversal_view", "public_resource_scoped"})
POSITIVE.add("checkpoints")
POSITIVE.add("selection_policies")
POSITIVE.add("io_bridge")
POSITIVE.update({"family_sequence", "family_origins"})
POSITIVE.update({"async_recovery", "async_attempt", "outcome_fold", "recovery_owned", "recovery_native"})
POSITIVE.update({"erased_storage", "erased_depth", "io_engine", "io_depth", "io_finalization", "io_laws"})
POSITIVE.update({"io_family", "io_operations", "io_resources"})
POSITIVE.update({"io_budget", "io_stepping"})
POSITIVE.update({"fiber_basics", "fiber_drain", "fiber_reporting", "fiber_churn", "fiber_snapshot"})
POSITIVE.update({"capability_family", "capability_cancel", "capability_spawn", "cancel_laws", "spawn_laws"})
POSITIVE.add("fiber_race_pair")
POSITIVE.add("fiber_supervisor")
POSITIVE.add("capability_lifting")
POSITIVE.add("capability_concurrent")
POSITIVE.add("capability_temporal")
POSITIVE.add("test_control")
POSITIVE.add("capability_real_time")
POSITIVE.add("os_layer")
POSITIVE.update({"foreign_completion", "foreign_signal"})
POSITIVE.update({"wstp_support", "wstp_queues", "wstp_timers"})
POSITIVE.add("wstp_parking")
POSITIVE.add("host_notifier")
POSITIVE.update({"blocking_pool", "capability_blocking"})
POSITIVE.add("poller")
POSITIVE.update({"run_parks", "descriptor_readiness", "syncio_waits"})
RACE_CLIENTS = {"race_oneshot", "race_stack", "race_record", "race_supervisor", "race_registrations"}
POSITIVE.update(RACE_CLIENTS)
# Payload thread safety: erasure's pointer check and the opt-in assertion.
POSITIVE.add("public_thread_transferable")
# The race clients run on OS threads, as foreign_completion does.
CLIENT_COMPILE_TIMEOUTS = {name: 360 for name in RACE_CLIENTS}
# Concurrent traversal (AsyncPar), its completion group and the
# closable stack's detach, and the rejections of the parallel entry points.
PAR_CLIENTS = {"par_traverse", "par_traverse_failure", "par_traverse_bounded", "par_traverse_depth",
               "par_traverse_limit", "par_laws", "par_fluent", "race_par_group", "race_stack_take"}
POSITIVE.update(PAR_CLIENTS)
CLIENT_COMPILE_TIMEOUTS.update({name: 900 for name in PAR_CLIENTS})
CLIENT_COMPILE_TIMEOUTS.update({name: 600 for name in (
    "public_reject_par_traverse_sync", "public_reject_par_traverse_n_family", "public_reject_par_traverse_closure")})
# Parallel through OptionalT and ResultT, and its rejection for
# ReaderT, StateT and WriterT in explicit, inferred and fluent form.
PAR_CLIENTS.add("par_layers")
POSITIVE.add("par_layers")
CLIENT_COMPILE_TIMEOUTS["par_layers"] = 900
CLIENT_COMPILE_TIMEOUTS.update({f"reject_par_{layer}_{form}": 600 for layer in ("reader", "state", "writer") for form in ("explicit", "inferred", "fluent")})
# One million bounded elements take about 40 s at O0.
CLIENT_EXECUTION_TIMEOUTS = {"par_traverse_depth": 300}
# The work-stealing pool's own clients; timers and descriptor waits in each
# worker's own heap and poller; randomized operation mixes on both profiles.
WSTP_CLIENTS = {"wstp_parallel", "wstp_wakes", "wstp_ownership", "wstp_lifo", "wstp_worker_timers", "wstp_blocking", "wstp_stress"}
POSITIVE.update(WSTP_CLIENTS)
CLIENT_COMPILE_TIMEOUTS.update({name: 600 for name in WSTP_CLIENTS})
# The public Runtime, its shutdown, and run on its own worker.
RUNTIME_CLIENTS = {"public_runtime", "wstp_shutdown", "runtime_own_worker"}
POSITIVE.update(RUNTIME_CLIENTS)
CLIENT_COMPILE_TIMEOUTS.update({name: 600 for name in RUNTIME_CLIENTS})
CLIENT_COMPILE_TIMEOUTS.update({name: 360 for name in ("public_reject_runtime_profile", "public_reject_runtime_config")})
# A long-lived Runtime's flat footprint, and the bounded stack
# on both profiles, with 1 MiB pool worker stacks.
STORAGE_CLIENTS = {"storage_soak", "stack_profiles"}
POSITIVE.update(STORAGE_CLIENTS)
CLIENT_COMPILE_TIMEOUTS.update({name: 600 for name in STORAGE_CLIENTS})
# About 10 s at O0 on an idle host, each run twice with the bounded stack.
CLIENT_EXECUTION_TIMEOUTS.update({"stack_profiles": 120, "storage_soak": 60})
# Execution contexts, eval_on on every kind of target.
CONTEXT_CLIENTS = {"eval_on_basics", "eval_on_cancel", "eval_on_lifetime", "eval_on_laws", "eval_on_background"}
POSITIVE.update(CONTEXT_CLIENTS)
CLIENT_COMPILE_TIMEOUTS.update({name: 600 for name in CONTEXT_CLIENTS})
CLIENT_COMPILE_TIMEOUTS.update({name: 600 for name in ("public_reject_eval_on_fiber", "public_reject_eval_on_supervisor")})
# Seeded exploration and replay under TestControl, 1,000 seeds
# each by default (`--seeds A:B`, `--replay TRACE`; see state_machine/exploration.mojo).
EXPLORE_CLIENTS = {"explore_fibers", "explore_par", "explore_mutation"}
POSITIVE.update(EXPLORE_CLIENTS)
CLIENT_COMPILE_TIMEOUTS.update({name: 600 for name in EXPLORE_CLIENTS})
CLIENT_EXECUTION_TIMEOUTS.update({name: 120 for name in EXPLORE_CLIENTS})
# Clients that also run on the work-stealing profile: two more routes each,
# from source and package, built with POOL_DEFINES, which every public `run`
# reads (`host.mojo`). Their Driver and TestControl parts stay on the
# current-thread profile. The work-stealing profile is the default, so every
# client's own routes select the current-thread profile explicitly
# (CURRENT_DEFINES), keeping both profiles qualified and every client's
# existing checks on the profile they were written for.
POOL_DEFINES = ("FP_ASYNC_PROFILE=work_stealing",)
CURRENT_DEFINES = ("FP_ASYNC_PROFILE=current_thread",)
POOL_CLIENTS = {
    "fiber_basics", "fiber_drain", "fiber_race_pair", "fiber_reporting", "fiber_supervisor", "fiber_churn", "fiber_snapshot",
    "capability_family", "capability_cancel", "capability_spawn", "capability_concurrent", "capability_lifting",
    "capability_temporal", "capability_real_time", "capability_blocking",
    "cancel_laws", "spawn_laws", "io_laws",
    "async_coordination", "coordination_family", "coordination_origins", "coordination_owned",
    "racing", "racing_origins", "foreign_completion", "foreign_signal",
    "descriptor_readiness", "instant_timers", "timeouts", "run_parks",
    "blocking_pool", "syncio_waits", "storage_soak",
} | WSTP_CLIENTS | CONTEXT_CLIENTS
# The layers' Parallel runs on both profiles.
POOL_CLIENTS.add("par_layers")
# Failures that stop their siblings recover, as in Cats Effect.
PAR_CLIENTS.add("recover_after_stop")
POSITIVE.add("recover_after_stop")
CLIENT_COMPILE_TIMEOUTS["recover_after_stop"] = 900
POOL_CLIENTS.add("recover_after_stop")


def experiment_inputs():
    return {str(p.relative_to(ROOT)): sha(p)
            for p in sorted(EXPERIMENT.rglob("*"))
            if p.is_file() and "__pycache__" not in p.parts}


def case_of(specification):
    """Rebuild a record's compile case; JSON turned its tuples into lists."""
    values = dict(specification)
    for key in ("reject", "defines"):
        if isinstance(values.get(key), list):
            values[key] = tuple(values[key])
    return CompileCase(**values)


def audit_report(report, folder):
    """Re-derive a finished run's outcomes from its raw evidence, in the same checkout."""
    failures = []
    try:
        folder = Path(folder).resolve()
        binaries = audit_run_paths(report, folder)
        if (run_inputs(report["inputs"]) != run_inputs(inputs()) or report["experiment_inputs"] != experiment_inputs()
                or report.get("inputs_unchanged") is not True or report.get("experiment_unchanged") is not True):
            raise ValueError("changed immutable qualification inputs")
        builds = report["package_compilations"]
        if len(builds) != 2 or not all(accepted(b) and audit_command(b) for b in builds):
            raise ValueError("package compilation evidence")
        records = report["records"]
        if not records:
            raise ValueError("no checks")
        names = set()
        for record in records:
            case = case_of(record["specification"])
            name = f"{Path(case.source).stem}-{record['route']}-O{case.optimization}"
            if name in names:
                raise ValueError(f"duplicate check {name}")
            names.add(name)
            errors = audit_case(case, record, binaries / name, folder=folder)
            stack = record.get("bounded_stack")
            if stack is not None and not (accepted(stack) and audit_command(stack)
                                          and hashlib.sha256(stack["stdout"].encode()).hexdigest() == case.stdout_sha256):
                errors.append("bounded-stack execution")
            if errors or not record["passed"] or record["audit_failures"]:
                raise ValueError(name + ": " + "; ".join(errors or record["audit_failures"] or ["failed"]))
        failures += audit_artifacts(report, folder)
    except (ValueError, KeyError, TypeError, OSError, AttributeError, IndexError) as error:
        failures.append(str(error))
    return failures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--output", help="Fresh retained run directory within the checkout")
    modes.add_argument("--audit", help="Recheck a finished bundle without running the toolchain")
    parser.add_argument("--jobs", type=positive_int, default=2)
    parser.add_argument("--client", action="append", default=[], help="Qualify only the named client stem; repeat to select several")
    args = parser.parse_args()
    if Path.cwd().resolve() != ROOT:
        parser.error("Run from the repository root")
    if args.audit:
        folder = (ROOT / args.audit).resolve()
        errors = audit_report(json.loads((folder / "report.json").read_text()), folder)
        print("PASS" if not errors else "FAIL", errors)
        return bool(errors)
    clients = sorted((EXPERIMENT / "tests").glob("*.mojo"))
    clients += [ROOT / path for path in REGRESSIONS]
    known = {p.stem for p in clients}
    if len(known) != len(clients):
        raise SystemExit("Client stems must be unique to preserve separate evidence")
    if set(args.client) - known:
        parser.error("Unknown clients: " + ", ".join(sorted(set(args.client) - known)))
    if {p.stem for p in clients if p.stem in POSITIVE} != POSITIVE:
        raise SystemExit("Missing declared positive client")
    if not POOL_CLIENTS <= POSITIVE:
        raise SystemExit("Pool clients must be declared positive clients")
    selected = sorted(set(args.client)) or None
    if selected:
        clients = [p for p in clients if p.stem in selected]
    run = RunContext.start(args.output, "state-machines")
    before = experiment_inputs()
    # Preserve the immutable input evidence even if the execution service stops
    # the launcher before its final aggregate report can be written.
    write_json(run.folder / "started.json", dict(
        **run.metadata(), experiment_inputs=before, selected_clients=selected))
    source = run.folder / "source"
    shutil.copytree(ROOT / "src/fp", source / "fp")
    shutil.copytree(EXPERIMENT / "state_machine", source / "state_machine")
    shutil.copytree(EXPERIMENT / "tests", run.folder / "test-snapshot")
    package = run.folder / "package"
    package.mkdir()
    builds = []
    for name, include in (("fp", source), ("state_machine", package)):
        built = precompile(package / f"{name}.mojoc", run.folder / f"{name}.log",
                           source=str(source / name), include=str(include), timeout=300)
        builds.append(built)
        write_json(run.folder / "package-compilations.json", builds)
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
        expected = (None if errors else REGRESSION_STDOUT.get(client.stem, "")
                    if regression else client.with_suffix(".stdout").read_text())
        routes = [("source", source, CURRENT_DEFINES), ("package", package, CURRENT_DEFINES)]
        if client.stem in POOL_CLIENTS:
            routes += [("source-pool", source, POOL_DEFINES), ("package-pool", package, POOL_DEFINES)]
        for route, include, defines in routes:
            for level in (0, 3):
                case = CompileCase.from_source(
                    str(client.relative_to(ROOT)), level, include=str(include),
                    reject=errors or None, expected_stdout=expected, defines=defines,
                    memory_limit_bytes=(3 if client.stem in PUBLIC_EXAMPLES or client.stem.startswith("public_") else 6) * 1024**3,
                    werror=True, compiler_threads=1, compile_timeout={"async_masking": 600, "io_bridge": 600, "scheduler": 600, **{name: 900 for name in PUBLIC_EXAMPLES | {"public_generic", "public_resources", "public_owned", "public_extension", "public_traversal_view", "public_resource_scoped"}}, "host_admission": 600, "extension_boundary": 600, "instant_timers": 600, "instant_cleanup": 900, "io_native_errors": 600, "coordination_family": 900, "depth": 360, "racing_origins": 240, "timeouts": 600, "selection_policies": 600, "resource_composition": 900, "resource_lifecycle": 900, "resource_owned": 600, "resource_release_factory": 600, "pipeline_attempt": 600, "pipeline_recovery_native": 900, "outcome_fold": 360, "recovery_native": 900, "async_recovery": 600, "async_attempt": 600, "recovery_owned": 600, "family_sequence": 360, "family_origins": 600, "workload": 360, "io_engine": 360, "io_depth": 360, "io_finalization": 360, "io_laws": 360, "io_family": 600, "io_operations": 600, "io_resources": 600, "async_coordination": 600, "coordination_origins": 600, "coordination_owned": 600, "io_budget": 600, "io_stepping": 600, "fiber_basics": 600, "fiber_drain": 600, "fiber_reporting": 600, "fiber_churn": 600, "fiber_snapshot": 600, "public_reject_fiber_moved": 600, "public_reject_fiber_error": 600, "capability_family": 600, "fiber_race_pair": 600, "fiber_supervisor": 600, "capability_cancel": 900, "capability_spawn": 600, "cancel_laws": 900, "spawn_laws": 600, "public_reject_spawn_sync": 600, "reject_capability_narrow": 600, "public_reject_raise_type": 600, "capability_lifting": 900, "reject_lift_cancel_reader": 600, "reject_lift_spawn_state": 600, "reject_lift_defer_reader": 600, "reject_reader_environment_escape": 600, "capability_concurrent": 900, "public_reject_concurrent_sync": 600, "public_reject_ref_get_move_only": 600, "public_reject_ref_closure": 600, "capability_temporal": 900, "public_reject_temporal_sync": 600, "reject_lift_temporal_state": 600, "test_control": 900, "os_layer": 360, "foreign_completion": 360, "foreign_signal": 360, "host_notifier": 600, **CLIENT_COMPILE_TIMEOUTS, "blocking_pool": 600, "capability_blocking": 900, "public_reject_blocking_closure": 600, "public_reject_interruption_escape": 600, "public_reject_blocking_family": 600, "capability_real_time": 900, "public_reject_real_time_family": 600, "public_reject_real_time_instant": 600, "reject_lift_real_time_base": 600, "run_parks": 600, "descriptor_readiness": 600, "syncio_waits": 600, "public_reject_descriptor_int": 600, "public_reject_park_test_control": 600, "public_thread_transferable": 600, "public_reject_payload_pointer": 600, "reject_payload_borrow": 360, "public_reject_transferable_shared": 360}.get(client.stem, 120),
                    execution_timeout={"composition": 90, "io_depth": 120, "fiber_churn": 300, **CLIENT_EXECUTION_TIMEOUTS}.get(client.stem, 15))
                jobs.append((route, case))

    def check(job):
        route, case = job
        name = f"{Path(case.source).stem}-{route}-O{case.optimization}"
        binary = run.binaries / name
        result = execute_case(case, binary, run.folder / "cases" / name)
        audit = audit_case(case, result, binary, folder=run.folder)
        bounded_stack = None
        if result["passed"] and not audit and Path(case.source).stem in {"composition", "loop_lifecycle", "depth", "erased_depth", "io_depth", "io_family", "io_budget", "fiber_churn", "par_traverse_depth", "stack_profiles"}:
            # Apply the stack limit to execution only, never to the compiler.
            bounded_stack = command(
                ["bash", "-c", 'ulimit -s 1024\nexec "$1"', "bounded-stack", str(binary)],
                run.folder / "cases" / f"{name}.stack.log", timeout=case.execution_timeout)
            if not (accepted(bounded_stack) and audit_command(bounded_stack)
                    and hashlib.sha256(bounded_stack["stdout"].encode()).hexdigest() == case.stdout_sha256):
                audit.append("execution with 1024 KiB stack failed")
        record = dict(route=route, specification=asdict(case), **result, audit_failures=audit,
                      bounded_stack=bounded_stack, stack_limit_kib=1024 if bounded_stack else None)
        write_json(run.folder / "cases" / f"{name}.json", record)
        print("PASS" if result["passed"] and not audit else "FAIL", name, flush=True)
        return record

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
