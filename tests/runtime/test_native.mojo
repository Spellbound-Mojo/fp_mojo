from std.testing import assert_equal
from std.utils import Variant


def apply[A: Movable, R: Movable, //, F: def(A) -> R](func: F, value: A) -> R:
    return func(value)


@fieldwise_init
struct Left(Copyable, Movable):
    var value: Int


@fieldwise_init
struct Right(Movable):
    var value: Int


def main() raises:
    var amount = 5
    def add(value: Int) {var amount} -> Int:
        return value + amount
    amount = 50
    assert_equal(apply(add, 4), 9)
    assert_equal(apply(add, 8), 13)
    var seen = 0
    def track(value: Int) {mut seen} -> Int:
        seen += 1
        return value + seen
    assert_equal(apply(track, 8), 9)
    assert_equal(apply(track, 8), 10)
    var value = Variant[Left, Right](Right(42))
    assert_equal(value.isa[Right](), True)
    assert_equal(value[Right].value, 42)
    var payload = value^.unwrap[Right]()
    assert_equal(payload.value, 42)

