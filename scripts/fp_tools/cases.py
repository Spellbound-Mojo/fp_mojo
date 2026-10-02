"""Immutable compilation contracts, shared execution and raw evidence checks.

Inventories construct these specifications before running a compiler. Auditors
reconstruct them from maintained sources/manifests, never child pass flags.
"""
from dataclasses import dataclass
import hashlib
from pathlib import Path
import re
import shutil

from .runtime import (ROOT, accepted, audit_command, cache_populated, command, isolated_cache,
                      normalized, resolved, sha, timed_argv)


@dataclass(frozen=True)
class CompileCase:
    source: str
    source_sha256: str
    optimization: int
    include: str | None = "src"
    werror: bool = True
    reject: tuple[str, ...] | None = None
    stdout_sha256: str | None = None
    compile_timeout: int = 180
    execution_timeout: int = 60
    compiler_threads: int | None = None
    memory_limit_bytes: int | None = None
    measured: bool = False
    # Compile with a fresh, task-owned Mojo cache; removed after compilation.
    cold_cache: bool = False

    def __post_init__(self):
        if type(self.optimization) is not int or self.optimization not in (0, 3):
            raise ValueError("Unsupported optimization level")
        if type(self.werror) is not bool:
            raise ValueError("Warning policy must be explicit")
        if type(self.measured) is not bool:
            raise ValueError("Measurement policy must be explicit")
        if type(self.cold_cache) is not bool:
            raise ValueError("Cache policy must be explicit")
        for budget in (self.compiler_threads, self.memory_limit_bytes):
            if budget is not None and (type(budget) is not int or budget <= 0):
                raise ValueError("Resource budgets must be positive integers")
        if not isinstance(self.source, str) or not self.source:
            raise ValueError("Missing source")
        if self.reject is not None:
            if (not isinstance(self.reject, tuple) or not self.reject
                    or any(not isinstance(s, str) or not s for s in self.reject)
                    or self.stdout_sha256 is not None):
                raise ValueError("Rejections require immutable diagnostics and no execution")
        if not re.fullmatch(r"[0-9a-f]{64}", self.source_sha256):
            raise ValueError("Missing source hash")

    @classmethod
    def from_source(cls, source, optimization, *, expected_stdout=None, root=ROOT, **policy):
        path = Path(source)
        return cls(
            str(source), sha(root / path), optimization,
            stdout_sha256=(hashlib.sha256(expected_stdout.encode()).hexdigest()
                           if expected_stdout is not None else None),
            **policy,
        )

    def argv(self, executable):
        return ["mojo", "build", *(["-I", self.include] if self.include is not None else []),
                *(["-j", str(self.compiler_threads)] if self.compiler_threads is not None else []),
                f"-O{self.optimization}", *(["--Werror"] if self.werror else []),
                self.source, "-o", str(executable)]


def execute_case(case, executable, prefix):
    """A rejected program is compile-only even after unexpected acceptance."""
    executable, prefix = Path(executable), Path(prefix)
    executable.parent.mkdir(parents=True, exist_ok=True)
    if executable.exists():
        raise FileExistsError(f"Executable path already used: {executable}")
    env = cache = None
    if case.cold_cache:
        directory = prefix.with_suffix(".mojo-cache")
        env, location = isolated_cache(directory)
        if cache_populated(location):
            raise RuntimeError(f"Cold cache is not empty: {location}")
        cache = dict(location=normalized(location), populated_before=False)
    try:
        compiled = command(case.argv(executable), prefix.with_suffix(".compile.log"),
                           timeout=case.compile_timeout, env=env, timed=case.measured,
                           memory_limit_bytes=case.memory_limit_bytes)
    finally:
        if case.cold_cache:
            # Only this case's own cache directory is removed.
            shutil.rmtree(directory, ignore_errors=True)
    if cache is not None:
        compiled["cache"] = cache
    execution = None
    ok = accepted(compiled, case.reject)
    if case.werror and re.search(r"\bwarning:", compiled["stdout"] + compiled["stderr"], re.I):
        ok = False
    if case.reject is None and ok:
        execution = command([executable], prefix.with_suffix(".run.log"),
                            timeout=case.execution_timeout)
        ok = accepted(execution)
        if case.stdout_sha256 is not None:
            ok = ok and hashlib.sha256(execution["stdout"].encode()).hexdigest() == case.stdout_sha256
    return dict(compilation=compiled, execution=execution, passed=ok,
                executable_sha256=sha(executable) if executable.is_file() else None)


def audit_case(case, record, executable, *, root=ROOT, folder=None):
    """Check invocations, raw logs, outcomes and files independently of summaries."""
    failures = []
    try:
        executable = Path(executable).resolve()
        if not executable.is_relative_to(root.resolve()):
            raise ValueError("executable outside project")
        if folder is not None and not executable.is_relative_to(Path(folder).resolve() / "executables"):
            raise ValueError("executable outside run bundle")
        if sha(root / case.source) != case.source_sha256:
            raise ValueError("source changed")
        compiled = record.get("compilation")
        if not accepted(compiled, case.reject) or not audit_command(compiled, root):
            raise ValueError("compilation outcome/diagnostic/raw log")
        expected = timed_argv(case.argv(executable)) if case.measured else case.argv(executable)
        if ([normalized(x, root) for x in compiled.get("command", [])]
                != [normalized(x, root) for x in expected]):
            raise ValueError("compilation invocation")
        if compiled.get('memory_limit_bytes') != case.memory_limit_bytes:
            raise ValueError("compilation memory policy")
        cache = compiled.get("cache")
        if case.cold_cache != (cache is not None) or (
                cache is not None and (cache.get("populated_before") is not False
                                       or (folder is not None and not resolved(cache["location"], root)
                                           .resolve().is_relative_to(Path(folder).resolve())))):
            raise ValueError("compilation cache policy")
        if case.werror and re.search(r"\bwarning:", compiled["stdout"] + compiled["stderr"], re.I):
            raise ValueError("strict warning policy")
        execution = record.get("execution")
        if case.reject is not None:
            if execution is not None:
                raise ValueError("rejection program must never execute")
        else:
            if not accepted(execution) or not audit_command(execution, root):
                raise ValueError("missing/failed/inconsistent execution")
            if ([normalized(x, root) for x in execution.get("command", [])]
                    != [normalized(executable, root)]):
                raise ValueError("wrong executable")
            if not executable.is_file() or record.get("executable_sha256") != sha(executable):
                raise ValueError("executable missing/changed")
            if (case.stdout_sha256 is not None
                    and hashlib.sha256(execution["stdout"].encode()).hexdigest() != case.stdout_sha256):
                raise ValueError("incomplete/incorrect observations")
        if folder is not None:
            for result in (compiled, execution):
                if result is not None:
                    log = root / result["log"].replace("<PROJECT>", str(root))
                    if not log.resolve().is_relative_to(Path(folder).resolve()):
                        raise ValueError("raw log outside run bundle")
    except (ValueError, KeyError, TypeError, OSError, AttributeError) as error:
        failures.append(str(error))
    return failures
