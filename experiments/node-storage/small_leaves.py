"""Write a variant of tests/benchmarks/bench_node.mojo whose Node leaves hold an Int32.

Inline leaves apply only to constructors of at most 4 bytes; the checked-in
benchmark's leaves hold an Int. The hand-written side is unchanged and the
values are small, so both sides still compute the same checksums.

    pixi run python experiments/node-storage/small_leaves.py .cache/node-storage/bench_node_small.mojo
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

CHANGES = [
    ('struct NodeLeaf(Copyable):\n    var value: Int\n', 'struct NodeLeaf(Copyable):\n    var value: Int32\n'),
    ('        return NodeLeaf(value % 7)\n', '        return NodeLeaf(Int32(value % 7))\n'),
    ('        return x[NodeLeaf].value\n', '        return Int(x[NodeLeaf].value)\n'),
    ('        lambda (l: NodeLeaf) -> Int: l.value,\n', '        lambda (l: NodeLeaf) -> Int: Int(l.value),\n'),
    ('        return NodeLeaf(value)\n', '        return NodeLeaf(Int32(value))\n'),
]


def main():
    text = (ROOT / 'tests' / 'benchmarks' / 'bench_node.mojo').read_text()
    for old, new in CHANGES:
        if text.count(old) != 1:
            sys.exit(f'small_leaves: expected one occurrence of:\n{old}')
        text = text.replace(old, new)
    out = Path(sys.argv[1])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text)
    print('wrote', out)


if __name__ == '__main__':
    main()
