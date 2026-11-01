"""Measure what admitting linear values would touch, by letting the compiler audit it.

Copies `src/fp` into a fresh folder under `.cache/linear-resources/`, applies the
bound changes of the selected layers, precompiles the copy with `--Werror`, and
groups the diagnostics by file. Optionally runs client programs against the copy.
Nothing in `src/` changes.

    pixi run python experiments/linear-resources/overlay.py --layers carriers --name run1
    pixi run python experiments/linear-resources/overlay.py --patch resources --name run2 \
        --client experiments/linear-resources/clients/linear_resource.mojo

Layers are textual bound changes listed below; patches are the modules beside
this script (`--patch resources` runs `patch_resources.py`).
"""
import argparse
import collections
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# Each patch: (file under src/fp, old text, new text, expected occurrences).
LAYERS = {
    # Sum-type storage and the carriers built on it: Cases/Choice, Ok/Err/Result, Outcome.
    'carriers': [
        ('adt/data.mojo',
         '    comptime Subject: Value\n    """The stored value: one constructor at a time."""',
         '    comptime Subject: Movable\n    """The stored value: one constructor at a time."""', 1),
        ('adt/data.mojo',
         '    comptime Case[i: Int]: Value\n    """The constructor at position `i`."""',
         '    comptime Case[i: Int]: Movable\n    """The constructor at position `i`."""', 1),
        ('adt/data.mojo',
         'struct Cases[*Ts: Value](CaseList):',
         'struct Cases[*Ts: Movable](CaseList):', 1),
        ('adt/data.mojo',
         '    comptime Case[i: Int]: Value = Self.Ts[i]',
         '    comptime Case[i: Int]: Movable = Self.Ts[i]', 1),
        ('adt/data.mojo',
         '    _ChoiceType, Movable,\n',
         '    _ChoiceType, Movable,\n    Deinitable where conforms_to(F.Layer[Node[F]].Subject, Deinitable),\n', 1),
        ('data/_result.mojo',
         'struct Ok[T: Movable & Deinitable](Movable, Copyable',
         'struct Ok[T: Movable](Movable, Deinitable where conforms_to(T, Deinitable), Copyable', 1),
        ('data/_result.mojo',
         'struct _ResultCases[T: Movable & Deinitable, E: Movable & Deinitable](Data):',
         'struct _ResultCases[T: Movable, E: Movable & Deinitable](Data):', 1),
        ('data/_result.mojo',
         'struct Result[T: Movable & Deinitable, E: Movable & Deinitable](\n'
         '    _ResultType, _ChoiceType, Movable, Copyable',
         'struct Result[T: Movable, E: Movable & Deinitable](\n'
         '    _ResultType, _ChoiceType, Movable, Deinitable where conforms_to(T, Deinitable), Copyable', 1),
        ('data/_result.mojo',
         '    comptime Value: Movable & Deinitable\n    comptime Error: Movable & Deinitable\n',
         '    comptime Value: Movable\n    comptime Error: Movable & Deinitable\n', 1),
        ('effects/outcomes.mojo',
         'comptime Outcome[T: Movable & Deinitable, E: Movable & Deinitable] =',
         'comptime Outcome[T: Movable, E: Movable & Deinitable] =', 1),
    ],
}

DIAGNOSTIC = re.compile(r'^(?P<path>[^:\s]+\.mojo):(?P<line>\d+):(?P<col>\d+): (?P<kind>error|warning): (?P<text>.*)$')


def apply(folder, layers):
    applied = []
    for layer in layers:
        for relative, old, new, expected in LAYERS[layer]:
            path = folder / 'fp' / relative
            text = path.read_text()
            found = text.count(old)
            if found != expected:
                sys.exit(f'{layer}: {relative}: expected {expected} occurrence(s), found {found}:\n{old}')
            path.write_text(text.replace(old, new))
            applied.append(f'{layer}: {relative}')
    return applied


def run(command, log, timeout):
    started = time.monotonic()
    with open(log, 'w') as out:
        try:
            code = subprocess.run(command, stdout=out, stderr=subprocess.STDOUT, cwd=ROOT, timeout=timeout).returncode
        except subprocess.TimeoutExpired:
            code = 'timeout'
    return code, time.monotonic() - started


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


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--layers', default='', help='Comma-separated layer names: ' + ', '.join(LAYERS))
    parser.add_argument('--name', required=True, help='Fresh folder name under .cache/linear-resources/')
    parser.add_argument('--patch', action='append', default=[], help='Patch module beside this script, e.g. resources')
    parser.add_argument('--parts', help='Comma-separated parts for the patch modules (default: all)')
    parser.add_argument('--client', action='append', default=[], help='Program to run against the overlay')
    parser.add_argument('--skip-package', action='store_true', help='Only run clients')
    parser.add_argument('--timeout', type=int, default=900)
    args = parser.parse_args()

    folder = ROOT / '.cache' / 'linear-resources' / args.name
    if folder.exists():
        sys.exit(f'{folder} exists; choose a fresh --name')
    shutil.copytree(ROOT / 'src' / 'fp', folder / 'fp')
    layers = [layer for layer in args.layers.split(',') if layer]
    for layer in layers:
        if layer not in LAYERS:
            sys.exit(f'unknown layer {layer}')
    for item in apply(folder, layers):
        print('patched', item)
    for name in args.patch:
        sys.path.insert(0, str(Path(__file__).parent))
        module = __import__(f'patch_{name}')
        if args.parts:
            module.patch(folder, tuple(args.parts.split(',')))
        else:
            module.patch(folder)
        print('patched', f'patch_{name}.py')

    if not args.skip_package:
        log = folder / 'package.log'
        code, seconds = run(['mojo', 'precompile', '-I', str(folder), '--Werror', str(folder / 'fp'),
                             '-o', str(folder / 'fp.mojoc')], log, args.timeout)
        errors, first = summarize(log, folder)
        print(f'package: exit={code} seconds={seconds:.0f} errors={sum(errors.values())}')
        for path, count in errors.most_common():
            print(f'  {count:4d}  {path}  first at {first[path]}')

    for client in args.client:
        name = Path(client).stem
        log = folder / f'{name}.log'
        code, seconds = run(['mojo', 'run', '-I', str(folder), client], log, args.timeout)
        print(f'client {name}: exit={code} seconds={seconds:.0f}')
        lines = [line for line in Path(log).read_text().splitlines()
                 if 'file_io_posix' not in line and 'directory_reader' not in line]
        print('  ' + '\n  '.join(lines[:40]))


if __name__ == '__main__':
    main()
