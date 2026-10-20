"""Chain lazy transformations and pass their native iterators to standard adapters."""
from fp.iteration import iterated
from std.collections.string import Codepoint
from std.iter import enumerate, iter
from std.testing import assert_equal


def codepoints_of(text: String) -> List[Codepoint]:
    return List(text.codepoints())


def main() raises:
    var words: List[String] = ["hello", "world"]
    var chars = (
        iterated(words^)
        .flat_map(codepoints_of)
        .to_list()
    )
    assert_equal(chars, List("helloworld".codepoints()))
    print("codepoints:", len(chars))

    # Standard adapters consume the wrapper through IterableOwned.
    var numbered = enumerate(iterated(range(4, 7)))
    var pairs = iterated(numbered^).collect_list()
    assert_equal(pairs, [(0, 4), (1, 5), (2, 6)])
    for pair in pairs:
        print(pair[0], pair[1])

    # Borrow explicitly when the collection should remain available.
    var values: List[Int] = [1, 2, 3]
    var copied = iterated(iter(values)).to_list()
    assert_equal(values, [1, 2, 3])
    assert_equal(copied, values)
