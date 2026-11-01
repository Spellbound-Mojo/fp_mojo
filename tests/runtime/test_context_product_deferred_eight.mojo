"""Deferred families still combine up to eight operands."""
from fp.functions import pipeline
from fp.effects import Reader, ask
from std.testing import assert_equal
def main() raises:
    comptime R = Reader[Int]
    var values = pipeline(ask[R]()).product_n((ask[R](), ask[R](), ask[R](), ask[R](), ask[R](), ask[R](), ask[R]())).run(3)
    assert_equal(values[7], 3)
