"""One set of operations, with explicit native context selection."""
from fp.algebra import (
    map, pure, flat_map, traverse,
    IdentityFamily, OptionalFamily, ResultFamily, ListFamily,
)


def twice(var value: Int) -> Int:
    return value * 2


def positive(var value: Int) -> Optional[Int]:
    return Optional(value) if value > 0 else Optional[Int]()


def main() raises:
    # The same mapper preserves each context's native representation.
    print("identity:", map[IdentityFamily](twice, 3))
    print("optional:", map[OptionalFamily](twice, Optional(3)).value())
    var checked = map[ResultFamily[Error]](twice, pure[ResultFamily[Error]](3))
    print("result:", checked^.raise_on_err())
    var values: List[Int] = [1, 2, 3]
    var doubled = map[ListFamily](twice, values^)
    print("list:", doubled[0], doubled[1], doubled[2])

    # flat_map lets the callback choose the next computation in that context.
    var absent = flat_map[OptionalFamily](positive, Optional(-1))
    print("positive -1 present:", Bool(absent))

    # Traverse collects the same source shape, or stops at the first absence.
    var valid: List[Int] = [1, 2, 3]
    var accepted = traverse[ListFamily, OptionalFamily](positive, valid^)
    print("traversed:", len(accepted.value()))
    var invalid: List[Int] = [1, -2, 3]
    var rejected = traverse[ListFamily, OptionalFamily](positive, invalid^)
    print("invalid traversal present:", Bool(rejected))
