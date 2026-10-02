"""Shared release tooling: bounded commands, immutable inputs and strict outcomes."""
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import signal
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
PIN = 'Mojo 1.1.0 (8189361e)'


def _appledouble_files(root):
    """macOS writes binary "._name" companions when it copies files to a
    non-Apple volume. Every source, fixture and document glob would read them,
    so the tooling refuses to run rather than build a wrong inventory."""
    found = []
    for folder, directories, files in os.walk(root):
        directories[:] = [d for d in directories if d not in ('.git', '.pixi', '.cache', '__pycache__')]
        found += [Path(folder, name) for name in files if name.startswith('._')]
    return found


if _stray := _appledouble_files(ROOT):
    raise SystemExit(f'{len(_stray)} macOS AppleDouble files (for example {_stray[0].relative_to(ROOT)}) '
                     "would be read as project files; remove them with: find . -name '._*' -not -path './.pixi/*' -delete")
CRASH = re.compile(r'Stack dump:|PLEASE submit a bug report|LLVM ERROR:|Assertion .*failed|Segmentation fault', re.I)


def positive_int(text):
    """Shared argparse conversion for bounded compilation/worker policies."""
    value = int(text)
    if value <= 0:
        raise ValueError('must be positive')
    return value


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2).replace(str(ROOT), '<PROJECT>') + '\n')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inputs(root=ROOT):
    paths = [p for folder in ('src', 'tests', 'scripts', 'benchmarks', '.github')
             for p in (root / folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts]
    paths += [p for p in (root / 'docs').rglob('*') if p.is_file() and '__pycache__' not in p.parts]
    paths += [root / name for name in ('README.md', 'pixi.toml', 'pixi.lock')]
    paths += [root / 'mkdocs.yml'] if (root / 'mkdocs.yml').is_file() else []
    return {str(p.relative_to(root)): sha(p) for p in sorted(paths)}


def input_changes(before, after):
    return sorted(k for k in before.keys() | after.keys() if before.get(k) != after.get(k))


def reserve_output(output):
    """Atomically reserve a fresh report directory, including concurrent starts."""
    folder = (ROOT / output).resolve()
    if not folder.is_relative_to(ROOT):
        raise ValueError('Output must remain within the project')
    folder.mkdir(parents=True, exist_ok=False)
    return folder


def binary_directory(folder, label):
    """Keep unique executable directories inside each retained run bundle."""
    folder = Path(folder).resolve()
    if not folder.is_relative_to(ROOT):
        raise ValueError('Executable directory must remain within the project')
    parent = folder / 'executables'
    parent.mkdir(parents=True, exist_ok=True)
    identity = hashlib.sha256(str(folder.resolve()).encode()).hexdigest()[:16]
    return Path(tempfile.mkdtemp(prefix=f'{label}-{identity}-', dir=parent))


def isolated_cache(directory):
    """Point Mojo at a task-owned compilation cache below directory.

    Returns the child environment and the verified cache location. Callers own
    removal of directory; user and project caches are never touched.
    """
    env = dict(os.environ, MODULAR_CACHE_DIR=str(directory))
    location = Path(subprocess.check_output(['mojo', '--print-cache-location'], env=env, text=True).strip())
    if not location.resolve().is_relative_to(Path(directory).resolve()):
        raise RuntimeError(f'Cache isolation failed: {location}')
    return env, location


def cache_populated(location):
    return Path(location).exists() and any(Path(location).rglob('*'))


def timed_argv(argv):
    """Native resource accounting, independent of the historical benchmark profile."""
    system = platform.system()
    if system not in ('Darwin', 'Linux'):
        raise RuntimeError('Resource accounting requires Linux or macOS')
    return ['/usr/bin/time', '-l' if system == 'Darwin' else '-v', *map(str, argv)]


def _linux_tree_rss(pid):
    """Sample this command's descendants only; never inspect unrelated jobs."""
    pending, seen, total = [pid], set(), 0
    while pending:
        child = pending.pop()
        if child in seen:
            continue
        seen.add(child)
        try:
            status = Path(f'/proc/{child}/status').read_text()
            match = re.search(r'^VmRSS:\s+(\d+)\s+kB', status, re.M)
            total += int(match[1]) * 1024 if match else 0
            pending.extend(map(int, Path(f'/proc/{child}/task/{child}/children').read_text().split()))
        except (FileNotFoundError, ProcessLookupError):
            pass  # A child can finish between the two reads.
    return total


def command(argv, log, timeout=180, env=None, timed=False, memory_limit_bytes=None):
    """Kill the whole process group on timeout; retain stdout and stderr separately."""
    if memory_limit_bytes is not None:
        if type(memory_limit_bytes) is not int or memory_limit_bytes <= 0:
            raise ValueError('Memory limit must be a positive byte count')
        if platform.system() != 'Linux':
            raise RuntimeError('RSS budget enforcement currently requires Linux')
    actual = timed_argv(argv) if timed else list(map(str, argv))
    start = time.perf_counter()
    process = subprocess.Popen(actual, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, start_new_session=True, env=env)
    expired, memory_exceeded, sampled_peak = False, False, 0
    while True:
        if memory_limit_bytes is not None:
            sampled_peak = max(sampled_peak, _linux_tree_rss(process.pid))
            memory_exceeded = sampled_peak > memory_limit_bytes
        remaining = timeout - (time.perf_counter() - start)
        expired = remaining <= 0
        if expired or memory_exceeded:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            out, err = process.communicate()
            break
        try:
            out, err = process.communicate(timeout=min(remaining, .1) if memory_limit_bytes else remaining)
            break
        except subprocess.TimeoutExpired:
            continue
    log.parent.mkdir(parents=True, exist_ok=True)
    marker = ('\nTIMEOUT\n' if expired else '') + ('\nMEMORY LIMIT\n' if memory_exceeded else '')
    log.write_text((out + err + marker).replace(str(ROOT), '<PROJECT>'))
    rss = re.search(r'(\d+)\s+maximum resident set size', err) if timed else None
    linux_rss = re.search(r'Maximum resident set size \(kbytes\):\s*(\d+)', err) if timed else None
    peak = int(rss[1]) if rss else int(linux_rss[1]) * 1024 if linux_rss else None
    return dict(command=actual, exit_code=process.returncode, timeout=expired,
                memory_limit_bytes=memory_limit_bytes, memory_limit_exceeded=memory_exceeded,
                sampled_tree_peak_rss_bytes=sampled_peak or None,
                crashed=bool(CRASH.search(out + err)) or (process.returncode < 0 and not expired and not memory_exceeded),
                seconds=time.perf_counter() - start, stdout=out, stderr=err,
                peak_rss_bytes=peak, log=str(log.resolve().relative_to(ROOT)))


def accepted(record, expected_errors=None):
    # Re-evaluate the diagnostic as well as flags: child reports cannot turn a
    # fatal compiler message into a pass by omitting or falsifying metadata.
    if not isinstance(record, dict) or any(k not in record for k in
            ('timeout', 'crashed', 'exit_code', 'stdout', 'stderr')):
        return False
    if (record['timeout'] is not False or record['crashed'] is not False
            or record.get('memory_limit_exceeded', False) is not False
            or not isinstance(record['stdout'], str) or not isinstance(record['stderr'], str)):
        return False
    if type(record['exit_code']) is not int:
        return False
    if CRASH.search(record['stdout'] + record['stderr']):
        return False
    if expected_errors is None:
        return record['exit_code'] == 0
    return (record['exit_code'] == 1 and bool(expected_errors)
            and all(isinstance(text, str) and text for text in expected_errors)
            and all(text in record['stdout'] + record['stderr'] for text in expected_errors))


def environment(*, measured=False):
    """Identify supported functional hosts; measurement admission stays narrower."""
    version = subprocess.check_output(['mojo', '--version'], text=True).strip()
    system, machine = platform.system(), platform.machine()
    if version != PIN or (system, machine) not in {('Darwin', 'arm64'), ('Linux', 'x86_64')}:
        raise RuntimeError(f'Requires {PIN} on macOS arm64 or Linux x86-64; found {version}, {platform.platform()}')
    if measured and (system, machine) != ('Darwin', 'arm64'):
        raise RuntimeError('Measurements require the pinned macOS arm64 profile; use --functional-only on Linux')
    if system == 'Darwin':
        cpu = subprocess.check_output(['sysctl', '-n', 'machdep.cpu.brand_string'], text=True).strip()
    else:
        cpu = next((line.split(':', 1)[1].strip() for line in Path('/proc/cpuinfo').read_text().splitlines()
                    if line.startswith('model name')), platform.processor() or machine)
    return dict(compiler=version, platform=platform.platform(), machine=platform.machine(),
                cpu=cpu,
                target=subprocess.check_output(['mojo', 'build', '--print-effective-target'], text=True).strip(),
                pixi=subprocess.check_output(['pixi', '--version'], text=True).strip())


def normalized(value, root=ROOT):
    return str(value).replace(str(root), '<PROJECT>')


def resolved(value, root=ROOT):
    return root / str(value).replace('<PROJECT>', str(root))


def audit_command(record, root=ROOT):
    """Bind stdout/stderr to the separately retained raw log, even for rejects."""
    try:
        log = resolved(record['log'], root).resolve()
        if not log.is_relative_to(root.resolve()) or not log.is_file(): return False
        raw = (record['stdout'] + record['stderr'] + ('\nTIMEOUT\n' if record['timeout'] else '')
               + ('\nMEMORY LIMIT\n' if record.get('memory_limit_exceeded') else ''))
        return log.read_text() == normalized(raw, root)
    except (KeyError, TypeError, OSError):
        return False
