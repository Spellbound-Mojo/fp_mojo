"""Literal no-return factories also accept pointers with symbolic input ABI."""
from fp.functions import as_unary, as_binary, tupled, untupled, first, second, split, merge, flow, Identity
from std.testing import assert_equal

def discard[T: Movable & Deinitable](var value: T): pass
def discard_pair[A: Movable & Deinitable, B: Movable & Deinitable](var first: A, var second: B): pass
def fail[T: Movable & Deinitable](var value: T) raises Int: raise 7
def fail_pair[A: Movable & Deinitable, B: Movable & Deinitable](var first: A, var second: B) raises Int: raise 8
def emit(): pass

def unary[T: Copyable & Deinitable](value: T) raises:
    var pointer: def(var T) thin = discard[T]
    as_unary(pointer)(value.copy())
    var projected = first[Int](pointer)((value.copy(), 3))
    assert_equal(projected[1], 3)
    var other = second[Int](pointer)((3, value.copy()))
    assert_equal(other[0], 3)
    var both = split(pointer, pointer)((value.copy(), value.copy()))
    comptime assert type_of(both) == Tuple[type_of(None), type_of(None)]
    _ = both
    var repeated = merge(pointer, pointer)(value.copy())
    comptime assert type_of(repeated) == Tuple[type_of(None), type_of(None)]
    _ = repeated
    flow(Identity[T](), pointer)(value.copy())
    flow(Identity[T](), Identity[T]()).then(pointer)(value.copy())
    var raising: def(var T) raises Int thin = fail[T]
    var observed = 0
    try: as_unary(raising)(value.copy())
    except error: observed = error
    assert_equal(observed, 7)

def binary[A: Copyable & Deinitable, B: Copyable & Deinitable](a: A, b: B) raises:
    var pointer: def(var A, var B) thin = discard_pair[A, B]
    as_binary(pointer)(a.copy(), b.copy())
    tupled(pointer)((a.copy(), b.copy()))
    var pair_pointer: def(var Tuple[A, B]) thin = discard[Tuple[A, B]]
    untupled[A, B](pair_pointer)(a.copy(), b.copy())
    var raising: def(var A, var B) raises Int thin = fail_pair[A, B]
    var observed = 0
    try: as_binary(raising)(a.copy(), b.copy())
    except error: observed = error
    assert_equal(observed, 8)
    try: tupled(raising)((a.copy(), b.copy()))
    except error: observed = error
    assert_equal(observed, 8)

def main() raises:
    var pointer: def() thin = emit
    _ = flow(pointer, Identity[type_of(None)]())()
    _ = flow(Identity[type_of(None)](), Identity[type_of(None)]()).compose(pointer)()
    unary(2)
    unary(String("x"))
    binary(2, 3)
    binary(2, String("y"))
    binary(String("x"), 3)
    binary(String("x"), String("y"))
