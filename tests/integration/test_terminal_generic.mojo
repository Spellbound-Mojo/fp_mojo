"""Two-layer terminal forwarding keeps native types across package imports."""
from fp.iteration import fold_left, reduce, reduce_optional, fold_until, ReductionError, EmptyReductionError
from fp.iteration import find, any, all
from fp.data import ControlFlow, Continue, Break
from std.iter import Iterator, iter
from std.testing import assert_equal, assert_true, assert_false
def fold_left_pure1[A: Movable & Deinitable, T: Movable & Deinitable, I: Iterator, //, F: def(var A, var T) -> A](f: F, var initial: A, var source: I) -> A where I.Element == T:
    return fold_left(f, initial^, source^)

def fold_left_pure2[A: Movable & Deinitable, T: Movable & Deinitable, I: Iterator, //, F: def(var A, var T) -> A](f: F, var initial: A, var source: I) -> A where I.Element == T:
    return fold_left_pure1(f, initial^, source^)

def reduce_initial_pure1[A: Movable & Deinitable, T: Movable & Deinitable, I: Iterator, //, F: def(var A, var T) -> A](f: F, var initial: A, var source: I) -> A where I.Element == T:
    return reduce(f, source^, initial=initial^)

def reduce_initial_pure2[A: Movable & Deinitable, T: Movable & Deinitable, I: Iterator, //, F: def(var A, var T) -> A](f: F, var initial: A, var source: I) -> A where I.Element == T:
    return reduce_initial_pure1(f, initial^, source^)

def reduce_optional_pure1[T: Movable & Deinitable, I: Iterator, //, F: def(var T, var T) -> T](f: F, var source: I) -> Optional[T] where I.Element == T:
    return reduce_optional(f, source^)

def reduce_optional_pure2[T: Movable & Deinitable, I: Iterator, //, F: def(var T, var T) -> T](f: F, var source: I) -> Optional[T] where I.Element == T:
    return reduce_optional_pure1(f, source^)

def reduce_pure1[T: Movable & Deinitable, I: Iterator, //, F: def(var T, var T) -> T](f: F, var source: I) raises EmptyReductionError -> T where I.Element == T:
    return reduce(f, source^)

def reduce_pure2[T: Movable & Deinitable, I: Iterator, //, F: def(var T, var T) -> T](f: F, var source: I) raises EmptyReductionError -> T where I.Element == T:
    return reduce_pure1(f, source^)

def fold_until_pure1[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, I: Iterator, //, F: def(var A, var T) -> ControlFlow[B, A]](f: F, var initial: A, var source: I) -> ControlFlow[B, A] where I.Element == T:
    return fold_until(f, initial^, source^)

def fold_until_pure2[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, I: Iterator, //, F: def(var A, var T) -> ControlFlow[B, A]](f: F, var initial: A, var source: I) -> ControlFlow[B, A] where I.Element == T:
    return fold_until_pure1(f, initial^, source^)

def find_pure1[T: Movable & Deinitable, I: Iterator, //, F: def(T) -> Bool](f: F, var source: I) -> Optional[T] where I.Element == T:
    return find(f, source^)

def find_pure2[T: Movable & Deinitable, I: Iterator, //, F: def(T) -> Bool](f: F, var source: I) -> Optional[T] where I.Element == T:
    return find_pure1(f, source^)

def any_pure1[T: Movable & Deinitable, I: Iterator, //, F: def(T) -> Bool](f: F, var source: I) -> Bool where I.Element == T:
    return any(f, source^)

def any_pure2[T: Movable & Deinitable, I: Iterator, //, F: def(T) -> Bool](f: F, var source: I) -> Bool where I.Element == T:
    return any_pure1(f, source^)

def all_pure1[T: Movable & Deinitable, I: Iterator, //, F: def(T) -> Bool](f: F, var source: I) -> Bool where I.Element == T:
    return all(f, source^)

def all_pure2[T: Movable & Deinitable, I: Iterator, //, F: def(T) -> Bool](f: F, var source: I) -> Bool where I.Element == T:
    return all_pure1(f, source^)

def fold_left_error1[A: Movable & Deinitable, T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(var A, var T) raises E -> A](f: F, var initial: A, var source: I) raises E -> A where I.Element == T:
    return fold_left[E=E](f, initial^, source^)

def fold_left_error2[A: Movable & Deinitable, T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(var A, var T) raises E -> A](f: F, var initial: A, var source: I) raises E -> A where I.Element == T:
    return fold_left_error1[E=E](f, initial^, source^)

def reduce_initial_error1[A: Movable & Deinitable, T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(var A, var T) raises E -> A](f: F, var initial: A, var source: I) raises E -> A where I.Element == T:
    return reduce[E=E](f, source^, initial=initial^)

def reduce_initial_error2[A: Movable & Deinitable, T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(var A, var T) raises E -> A](f: F, var initial: A, var source: I) raises E -> A where I.Element == T:
    return reduce_initial_error1[E=E](f, initial^, source^)

def reduce_optional_error1[T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(var T, var T) raises E -> T](f: F, var source: I) raises E -> Optional[T] where I.Element == T:
    return reduce_optional[E=E](f, source^)

def reduce_optional_error2[T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(var T, var T) raises E -> T](f: F, var source: I) raises E -> Optional[T] where I.Element == T:
    return reduce_optional_error1[E=E](f, source^)

def reduce_error1[T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(var T, var T) raises E -> T](f: F, var source: I) raises ReductionError[E] -> T where I.Element == T:
    return reduce[E=E](f, source^)

def reduce_error2[T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(var T, var T) raises E -> T](f: F, var source: I) raises ReductionError[E] -> T where I.Element == T:
    return reduce_error1[E=E](f, source^)

def fold_until_error1[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(var A, var T) raises E -> ControlFlow[B, A]](f: F, var initial: A, var source: I) raises E -> ControlFlow[B, A] where I.Element == T:
    return fold_until[E=E](f, initial^, source^)

def fold_until_error2[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(var A, var T) raises E -> ControlFlow[B, A]](f: F, var initial: A, var source: I) raises E -> ControlFlow[B, A] where I.Element == T:
    return fold_until_error1[E=E](f, initial^, source^)

def find_error1[T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(T) raises E -> Bool](f: F, var source: I) raises E -> Optional[T] where I.Element == T:
    return find[E=E](f, source^)

def find_error2[T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(T) raises E -> Bool](f: F, var source: I) raises E -> Optional[T] where I.Element == T:
    return find_error1[E=E](f, source^)

def any_error1[T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(T) raises E -> Bool](f: F, var source: I) raises E -> Bool where I.Element == T:
    return any[E=E](f, source^)

def any_error2[T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(T) raises E -> Bool](f: F, var source: I) raises E -> Bool where I.Element == T:
    return any_error1[E=E](f, source^)

def all_error1[T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(T) raises E -> Bool](f: F, var source: I) raises E -> Bool where I.Element == T:
    return all[E=E](f, source^)

def all_error2[T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(T) raises E -> Bool](f: F, var source: I) raises E -> Bool where I.Element == T:
    return all_error1[E=E](f, source^)

@fieldwise_init
struct Fault(Movable):
    var code: Int
@fieldwise_init
struct Halt(Movable):
    var value: String

def append(var a: String, var t: Int) -> String: return a + String(t)
def append_error(var a: String, var t: Int) raises Fault -> String: return a + String(t)
def add(var a: Int, var t: Int) -> Int: return a + t
def add_error(var a: Int, var t: Int) raises Fault -> Int: return a + t
def control(var a: String, var t: Int) -> ControlFlow[Halt, String]:
    return ControlFlow[Halt, String](Continue(a + String(t)))
def control_error(var a: String, var t: Int) raises Fault -> ControlFlow[Halt, String]:
    return ControlFlow[Halt, String](Continue(a + String(t)))
def pred(t: Int) -> Bool: return t == 1
def pred_error(t: Int) raises Fault -> Bool: return t == 1

def append_never(var a: String, var t: Int) raises Never -> String: return a + String(t)
def add_never(var a: Int, var t: Int) raises Never -> Int: return a + t
def control_never(var a: String, var t: Int) raises Never -> ControlFlow[Halt, String]:
    return ControlFlow[Halt, String](Continue(a + String(t)))
def pred_never(t: Int) raises Never -> Bool: return t == 1
def main() raises:
    assert_equal(fold_left_pure2(append, String("s"), iter(range(3))), "s012")
    assert_equal(reduce_initial_pure2(append, String("s"), iter(range(3))), "s012")
    var optional = reduce_optional_pure2(add, iter(range(4)))
    assert_equal(optional.take(), 6)
    assert_false(reduce_optional_pure2(add, iter(range(0))))
    var continued = fold_until_pure2(control, String("s"), iter(range(3)))
    assert_equal(continued^.unwrap[Continue[String]]().into_payload(), "s012")
    var found = find_pure2(pred, iter(range(3)))
    assert_equal(found.take(), 1)
    assert_true(any_pure2(pred, iter(range(3))))
    assert_false(all_pure2(pred, iter(range(3))))
    assert_false(find_pure2(pred, iter(range(0))))
    assert_false(any_pure2(pred, iter(range(0))))
    assert_true(all_pure2(pred, iter(range(0))))
    try:
        debug_assert[assert_mode="safe"](reduce_pure2(add, iter(range(4))) == 6)
    except: raise Error("unexpected empty")
    var empty = False
    try: _ = reduce_pure2(add, iter(range(0)))
    except error:
        comptime assert type_of(error) == EmptyReductionError
        empty = True
    assert_true(empty)
    try:
        debug_assert[assert_mode="safe"](fold_left_error2(append_error, String("s"), iter(range(3))) == "s012")
        debug_assert[assert_mode="safe"](reduce_initial_error2(append_error, String("s"), iter(range(3))) == "s012")
        var optional_error = reduce_optional_error2(add_error, iter(range(4)))
        debug_assert[assert_mode="safe"](optional_error.take() == 6)
        debug_assert[assert_mode="safe"](not reduce_optional_error2(add_error, iter(range(0))))
        var c = fold_until_error2(control_error, String("s"), iter(range(3)))
        debug_assert[assert_mode="safe"](c^.unwrap[Continue[String]]().into_payload() == "s012")
        var f = find_error2(pred_error, iter(range(3)))
        debug_assert[assert_mode="safe"](f.take() == 1)
        debug_assert[assert_mode="safe"](any_error2(pred_error, iter(range(3))))
        debug_assert[assert_mode="safe"](not all_error2(pred_error, iter(range(3))))
    except: raise Error("unexpected callback failure")
    try:
        debug_assert[assert_mode="safe"](reduce_error2(add_error, iter(range(4))) == 6)
    except: raise Error("unexpected reduction failure")
    # Explicit Never stays callable without a try boundary through two layers.
    assert_equal(fold_left_error2[E=Never](append_never, String("n"), iter(range(2))), "n01")
    assert_equal(reduce_initial_error2[E=Never](append_never, String("n"), iter(range(2))), "n01")
    var n = reduce_optional_error2[E=Never](add_never, iter(range(2)))
    assert_equal(n.take(), 1)
    var c = fold_until_error2[E=Never](control_never, String("n"), iter(range(2)))
    assert_equal(c^.unwrap[Continue[String]]().into_payload(), "n01")
    assert_true(any_error2[E=Never](pred_never, iter(range(2))))
    assert_false(all_error2[E=Never](pred_never, iter(range(2))))
    var f = find_error2[E=Never](pred_never, iter(range(2)))
    assert_equal(f.take(), 1)
    var never_empty = False
    try: _ = reduce_error2[E=Never](add_never, iter(range(0)))
    except error:
        comptime assert type_of(error) == ReductionError[Never]
        never_empty = error.isa[EmptyReductionError]()
    assert_true(never_empty)
    try:
        debug_assert[assert_mode="safe"](reduce_error2[E=Never](add_never, iter(range(3))) == 3)
    except: raise Error("unexpected Never reduction failure")
