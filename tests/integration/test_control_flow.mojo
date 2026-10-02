"""Generic forwarding, products, SIMD and external origins through control flow."""
from fp.control import while_loop, fori_loop, scan, ScanLengthError
from fp.callables import Binary
from std.testing import assert_equal
from std.iter import Iterator


def loop[A: Movable & Deinitable, F: def(var Int, var A) -> A](
    callback: F, var initial: A
) -> A:
    return fori_loop(0, 3, callback, initial^)


def scanning[A: Movable & Deinitable, X: Movable & Deinitable,
             Y: Movable & Deinitable, I: Iterator,
             F: def(var A, var X) -> Tuple[A, Y]](
    callback: F, var initial: A, var source: I
) raises ScanLengthError -> Tuple[A, List[Y]] where I.Element == X:
    return scan(callback, initial^, source^)


def annotate(var index: Int, var value: String) -> String:
    value += String(index)
    return value^


def text_step(var state: String, var item: Int) -> Tuple[String, Int]:
    state += String(item)
    var length = state.byte_length()
    return (state^, length)


def lanes(var index: Int, var value: SIMD[DType.int64, 4]) -> SIMD[DType.int64, 4]:
    return value + SIMD[DType.int64, 4](index)


@fieldwise_init
struct RefStep[o: ImmOrigin](Binary):
    comptime First = Pointer[Int, Self.o]
    comptime Second = Int
    comptime Out = Tuple[Pointer[Int, Self.o], Pointer[Int, Self.o]]
    def call(self, var carry: Pointer[Int, Self.o], var item: Int) -> Self.Out:
        return (carry, carry)


def external[o: ImmOrigin](ref[o] owner: Int) raises:
    var result = scan[Pointer[Int, o]](RefStep[o](), Pointer(to=owner), iter(range(3)))
    assert_equal(result[0][], owner)
    assert_equal(result[1][1][], owner)


def main() raises:
    assert_equal(loop(annotate, String("start:")), "start:012")
    assert_equal(loop(lanes, SIMD[DType.int64, 4](1)), SIMD[DType.int64, 4](4))
    var result = scanning(text_step, String("s"), iter(range(3)))
    assert_equal(result[0], "s012")
    assert_equal(result[1][2], 4)
    var owner = 42
    external(owner)
