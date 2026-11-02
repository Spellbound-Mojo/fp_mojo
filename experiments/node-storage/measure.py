"""Build the benchmark programs against several library variants and compare them.

Each variant is a name and an include folder: `src` for the checked-in library,
or an overlay folder made by `experiments/overlay.py`. Every benchmark program
is built at O3 once per variant, then run `--rounds` times with the variants
alternating inside each round, so drift on a shared host affects them alike.
The table gives, per benchmark line and variant, the range of the library and
native medians the programs printed and the median ratio.

    pixi run python experiments/node-storage/measure.py --rounds 3 \
        --variant base=src --variant cells=.cache/overlays/cells-1 \
        --bench tests/benchmarks/bench_node.mojo --bench tests/benchmarks/bench_match.mojo
"""
import argparse
import re
import statistics
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LINE = re.compile(r'^bench (\S+) native_ns=(\d+) library_ns=(\d+) samples=(\d+)$', re.M)


def build(variant, include, bench, folder):
    binary = folder / f'{variant}-{Path(bench).stem}'
    log = folder / f'{variant}-{Path(bench).stem}.build.log'
    with open(log, 'w') as out:
        code = subprocess.run(['mojo', 'build', '-O3', '-I', include, bench, '-o', str(binary)],
                              stdout=out, stderr=subprocess.STDOUT, cwd=ROOT, timeout=1800).returncode
    if code != 0:
        sys.exit(f'build failed for {variant} {bench}; see {log}')
    return binary


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--variant', action='append', required=True, help='name=include folder')
    parser.add_argument('--bench', action='append', required=True, help='Benchmark program')
    parser.add_argument('--rounds', type=int, default=3)
    parser.add_argument('--out', default='.cache/node-storage/measure', help='Folder for binaries and logs')
    args = parser.parse_args()

    folder = ROOT / args.out
    folder.mkdir(parents=True, exist_ok=True)
    variants = [tuple(item.split('=', 1)) for item in args.variant]
    binaries = {(name, bench): build(name, include, bench, folder) for name, include in variants for bench in args.bench}

    results = {}  # (bench line, variant) -> list of (native_ns, library_ns)
    order = []
    for round_index in range(args.rounds):
        names = [name for name, _ in variants]
        if round_index % 2:
            names.reverse()
        for name in names:
            for bench in args.bench:
                text = subprocess.run([str(binaries[(name, bench)])], capture_output=True, text=True,
                                      cwd=ROOT, timeout=1800).stdout
                for match in LINE.finditer(text):
                    key = match[1]
                    if key not in order:
                        order.append(key)
                    results.setdefault((key, name), []).append((int(match[2]), int(match[3])))

    print(f'{"benchmark":<17}{"variant":<12}{"library ms":>18}{"native ms":>18}{"ratio":>8}')
    for key in order:
        for name, _ in variants:
            samples = results.get((key, name), [])
            if not samples:
                continue
            native = [n / 1e6 for n, _ in samples]
            library = [l / 1e6 for _, l in samples]
            ratio = statistics.median(l / n for n, l in samples)
            print(f'{key:<17}{name:<12}{min(library):8.2f}–{max(library):<8.2f}{min(native):9.2f}–{max(native):<8.2f}{ratio:7.2f}x')


if __name__ == '__main__':
    main()
