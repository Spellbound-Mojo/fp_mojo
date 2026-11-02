"""Try a library change on a copy of `src/fp`, without touching `src/`.

Copies `src/fp` into a fresh folder under `.cache/overlays/`, applies the given
patch modules in order, precompiles the copy with `--Werror` (grouping any
diagnostics by file), and optionally runs client programs against it. A patch
module defines `patch(folder, parts)`, where `folder` holds the copied `fp`
package and `parts` is a tuple of the part names to apply, or None for all.

    pixi run python experiments/overlay.py --name cells-1 \
        --patch experiments/node-storage/patch_cells.py \
        --client tests/runtime/test_data_nodes.mojo

`experiments/node-storage/measure.py` builds and times benchmarks against an
overlay folder.
"""
import argparse
import collections
import importlib.util
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OVERLAYS = ROOT / '.cache' / 'overlays'

DIAGNOSTIC = re.compile(r'^(?P<path>[^:\s]+\.mojo):(?P<line>\d+):(?P<col>\d+): (?P<kind>error|warning): (?P<text>.*)$')
NOISE = ('file_io_posix', 'directory_reader')


def load_patch(path):
    path = Path(path).resolve()
    spec = importlib.util.spec_from_file_location(path.stem, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def create(name, patches, parts=None):
    """Copy `src/fp` to a fresh overlay folder and apply `patches` (paths)."""
    folder = OVERLAYS / name
    if folder.exists():
        sys.exit(f'{folder} exists; choose a fresh --name')
    shutil.copytree(ROOT / 'src' / 'fp', folder / 'fp')
    for path in patches:
        load_patch(path).patch(folder, parts)
        print('patched', path)
    return folder


def run(command, log, timeout):
    started = time.monotonic()
    with open(log, 'w') as out:
        try:
            code = subprocess.run(command, stdout=out, stderr=subprocess.STDOUT, cwd=ROOT, timeout=timeout).returncode
        except subprocess.TimeoutExpired:
            code = 'timeout'
    return code, time.monotonic() - started


def output(log):
    return [line for line in Path(log).read_text().splitlines() if not any(word in line for word in NOISE)]


def summarize(log, folder):
    errors = collections.Counter()
    first = {}
    for line in Path(log).read_text().splitlines():
        match = DIAGNOSTIC.match(line)
        if match and match['kind'] == 'error':
            path = match['path'].replace(str(folder) + '/', '')
            errors[path] += 1
            first.setdefault(path, f"{match['line']}: {match['text']}")
    return errors, first


def precompile(folder, timeout):
    log = folder / 'package.log'
    code, seconds = run(['mojo', 'precompile', '-I', str(folder), '--Werror', str(folder / 'fp'),
                         '-o', str(folder / 'fp.mojoc')], log, timeout)
    errors, first = summarize(log, folder)
    print(f'package: exit={code} seconds={seconds:.0f} errors={sum(errors.values())}')
    for path, count in errors.most_common():
        print(f'  {count:4d}  {path}  first at {first[path]}')
    return code == 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--name', required=True, help='Fresh folder name under .cache/overlays/')
    parser.add_argument('--patch', action='append', default=[], help='Patch module path; repeatable, applied in order')
    parser.add_argument('--parts', help='Comma-separated parts passed to every patch module (default: all)')
    parser.add_argument('--client', action='append', default=[], help='Program to run against the overlay')
    parser.add_argument('--skip-package', action='store_true', help='Only run clients')
    parser.add_argument('--timeout', type=int, default=900)
    args = parser.parse_args()

    parts = tuple(args.parts.split(',')) if args.parts else None
    folder = create(args.name, args.patch, parts)
    if not args.skip_package:
        precompile(folder, args.timeout)
    for client in args.client:
        log = folder / f'{Path(client).stem}.log'
        code, seconds = run(['mojo', 'run', '-I', str(folder), client], log, args.timeout)
        print(f'client {Path(client).stem}: exit={code} seconds={seconds:.0f}')
        print('  ' + '\n  '.join(output(log)[:40]))


if __name__ == '__main__':
    main()
