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
    print("identity:", map[IdentityFamily](3, twice))
    print("optional:", map[OptionalFamily](Optional(3), twice).value())
    var checked = map[ResultFamily[Error]](pure[ResultFamily[Error]](3), twice)
    print("result:", checked^.raise_on_err())
    var values: List[Int] = [1, 2, 3]
    var doubled = map[ListFamily](values^, twice)
    print("list:", doubled[0], doubled[1], doubled[2])

    # flat_map lets the callback choose the next computation in that context.
    var absent = flat_map[OptionalFamily](Optional(-1), positive)
    print("positive -1 present:", Bool(absent))

    # Traverse collects the same source shape, or stops at the first absence.
    var valid: List[Int] = [1, 2, 3]
    var accepted = traverse[ListFamily, OptionalFamily](valid^, positive)
    print("traversed:", len(accepted.value()))
    var invalid: List[Int] = [1, -2, 3]
    var rejected = traverse[ListFamily, OptionalFamily](invalid^, positive)
    print("invalid traversal present:", Bool(rejected))
