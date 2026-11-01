"""One set of operations; each infers its family from the value it receives."""
from fp.algebra import (
    map, pure, flat_map, traverse,
    IdentityFamily, ResultFamily,
)


def twice(var value: Int) -> Int:
    return value * 2


def positive(var value: Int) -> Optional[Int]:
    return Optional(value) if value > 0 else Optional[Int]()


def main() raises:
    # The same mapper preserves each context's native representation. A bare
    # value has no family of its own, so it names IdentityFamily.
    print("identity:", map[IdentityFamily](3, twice))
    print("optional:", map(Optional(3), twice).value())
    var checked = map(pure[ResultFamily[Error]](3), twice)
    print("result:", checked^.raise_on_err())
    var values: List[Int] = [1, 2, 3]
    var doubled = map(values^, twice)
    print("list:", doubled[0], doubled[1], doubled[2])

    # flat_map lets the callback choose the next computation in that context.
    var absent = flat_map(Optional(-1), positive)
    print("positive -1 present:", Bool(absent))

    # Traverse collects the same source shape, or stops at the first absence.
    # The callback's Optional result selects the target family.
    var valid: List[Int] = [1, 2, 3]
    var accepted = traverse(valid^, positive)
    print("traversed:", len(accepted.value()))
    var invalid: List[Int] = [1, -2, 3]
    var rejected = traverse(invalid^, positive)
    print("invalid traversal present:", Bool(rejected))
