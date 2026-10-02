"""Four native owner origins survive terminal results and exact failure channels."""
from fp.iteration import fold_left, reduce, reduce_optional, fold_until, ReductionError, ReductionStepError, EmptyReductionError
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
struct Item[T: Copyable & Deinitable, B: Copyable & Deinitable, E: Copyable & Deinitable](Copyable):
    var value: Self.T
    var stop: Self.B
    var error: Self.E

def keep[A: Movable & Deinitable, T: Movable & Deinitable](var a: A, var t: T) -> A: return a^
def keep_raising[A: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable](var a: A, var t: T) raises E -> A: return a^
def pick[T: Movable & Deinitable](value: T) -> Bool: return True
def pick_raising[T: Movable & Deinitable, E: Movable & Deinitable](value: T) raises E -> Bool: return True
def stop[A: Movable & Deinitable, T: Copyable & Deinitable, B: Copyable & Deinitable, E: Copyable & Deinitable](var a: A, var t: Item[T, B, E]) -> ControlFlow[B, A]:
    return ControlFlow[B, A](Break(t.stop.copy()))
def stop_raising[A: Movable & Deinitable, T: Copyable & Deinitable, B: Copyable & Deinitable, E: Copyable & Deinitable](var a: A, var t: Item[T, B, E]) raises E -> ControlFlow[B, A]:
    return ControlFlow[B, A](Break(t.stop.copy()))
def fail[A: Movable & Deinitable, T: Copyable & Deinitable, B: Copyable & Deinitable, E: Copyable & Deinitable](var a: A, var t: Item[T, B, E]) raises E -> A: raise t.error.copy()
def fail_control[A: Movable & Deinitable, T: Copyable & Deinitable, B: Copyable & Deinitable, E: Copyable & Deinitable](var a: A, var t: Item[T, B, E]) raises E -> ControlFlow[B, A]: raise t.error.copy()
def fail_predicate[T: Copyable & Deinitable, B: Copyable & Deinitable, E: Copyable & Deinitable](t: Item[T, B, E]) raises E -> Bool: raise t.error.copy()

def exercise(first: List[Int], second: List[Int], third: List[Int], fourth: List[Int]) raises:
    var acc = Span(first)
    var value = Span(second)
    var halted = Span(third)
    var failure = Span(fourth)
    comptime A = type_of(acc)
    comptime T = type_of(value)
    comptime B = type_of(halted)
    comptime E = type_of(failure)
    comptime V = Item[T, B, E]
    var values: List[V] = [V(value, halted, failure), V(value, halted, failure)]
    var a = fold_left_pure2(keep[A, V], acc, iter(values))
    assert_true(Pointer(to=a[0]) == Pointer(to=first[0]))
    var b = reduce_initial_pure2(keep[A, V], acc, iter(values))
    assert_true(Pointer(to=b[0]) == Pointer(to=first[0]))
    var c = fold_until_pure2(stop[A, T, B, E], acc, iter(values))
    var broken = c^.unwrap[Break[B]]().into_payload()
    assert_true(Pointer(to=broken[0]) == Pointer(to=third[0]))
    var found = find_pure2(pick[V], iter(values))
    assert_true(Pointer(to=found.value().value[0]) == Pointer(to=second[0]))
    assert_true(any_pure2(pick[V], iter(values)))
    assert_true(all_pure2(pick[V], iter(values)))
    var optional = reduce_optional_pure2(keep[V, V], iter(values))
    assert_true(Pointer(to=optional.value().value[0]) == Pointer(to=second[0]))
    try:
        var reduced = reduce_pure2(keep[V, V], iter(values))
        debug_assert[assert_mode="safe"](Pointer(to=reduced.value[0]) == Pointer(to=second[0]))
    except: raise Error("unexpected empty")
    try:
        var raised_a = fold_left_error2(keep_raising[A, V, E], acc, iter(values))
        debug_assert[assert_mode="safe"](Pointer(to=raised_a[0]) == Pointer(to=first[0]))
        var raised_b = reduce_initial_error2(keep_raising[A, V, E], acc, iter(values))
        debug_assert[assert_mode="safe"](Pointer(to=raised_b[0]) == Pointer(to=first[0]))
        var raised_c = fold_until_error2(stop_raising[A, T, B, E], acc, iter(values))
        var halted_c = raised_c^.unwrap[Break[B]]().into_payload()
        debug_assert[assert_mode="safe"](Pointer(to=halted_c[0]) == Pointer(to=third[0]))
        var raised_f = find_error2(pick_raising[V, E], iter(values))
        debug_assert[assert_mode="safe"](Pointer(to=raised_f.value().value[0]) == Pointer(to=second[0]))
        debug_assert[assert_mode="safe"](any_error2(pick_raising[V, E], iter(values)))
        debug_assert[assert_mode="safe"](all_error2(pick_raising[V, E], iter(values)))
        var raised_o = reduce_optional_error2(keep_raising[V, V, E], iter(values))
        debug_assert[assert_mode="safe"](Pointer(to=raised_o.value().value[0]) == Pointer(to=second[0]))
    except: raise Error("unexpected callback failure")
    try:
        var raised_r = reduce_error2(keep_raising[V, V, E], iter(values))
        debug_assert[assert_mode="safe"](Pointer(to=raised_r.value[0]) == Pointer(to=second[0]))
    except: raise Error("unexpected reduction failure")
    var caught_fold_left = False
    try: _ = fold_left_error2(fail[A, T, B, E], acc, iter(values))
    except error:
        comptime assert type_of(error) == E
        assert_true(Pointer(to=error[0]) == Pointer(to=fourth[0]))
        caught_fold_left = True
    assert_true(caught_fold_left)
    var caught_reduce_initial = False
    try: _ = reduce_initial_error2(fail[A, T, B, E], acc, iter(values))
    except error:
        comptime assert type_of(error) == E
        assert_true(Pointer(to=error[0]) == Pointer(to=fourth[0]))
        caught_reduce_initial = True
    assert_true(caught_reduce_initial)
    var caught_reduce_optional = False
    try: _ = reduce_optional_error2(fail[V, T, B, E], iter(values))
    except error:
        comptime assert type_of(error) == E
        assert_true(Pointer(to=error[0]) == Pointer(to=fourth[0]))
        caught_reduce_optional = True
    assert_true(caught_reduce_optional)
    var caught_fold_until = False
    try: _ = fold_until_error2(fail_control[A, T, B, E], acc, iter(values))
    except error:
        comptime assert type_of(error) == E
        assert_true(Pointer(to=error[0]) == Pointer(to=fourth[0]))
        caught_fold_until = True
    assert_true(caught_fold_until)
    var caught_find = False
    try: _ = find_error2(fail_predicate[T, B, E], iter(values))
    except error:
        comptime assert type_of(error) == E
        assert_true(Pointer(to=error[0]) == Pointer(to=fourth[0]))
        caught_find = True
    assert_true(caught_find)
    var caught_any = False
    try: _ = any_error2(fail_predicate[T, B, E], iter(values))
    except error:
        comptime assert type_of(error) == E
        assert_true(Pointer(to=error[0]) == Pointer(to=fourth[0]))
        caught_any = True
    assert_true(caught_any)
    var caught_all = False
    try: _ = all_error2(fail_predicate[T, B, E], iter(values))
    except error:
        comptime assert type_of(error) == E
        assert_true(Pointer(to=error[0]) == Pointer(to=fourth[0]))
        caught_all = True
    assert_true(caught_all)
    var caught_reduce = False
    try: _ = reduce_error2(fail[V, T, B, E], iter(values))
    except error:
        comptime assert type_of(error) == ReductionError[E]
        assert_true(error.isa[ReductionStepError[E]]())
        var exact = error^.unwrap[ReductionStepError[E]]().into_error()
        assert_true(Pointer(to=exact[0]) == Pointer(to=fourth[0]))
        caught_reduce = True
    assert_true(caught_reduce)
    assert_equal(acc[0] + value[0] + halted[0] + failure[0], 110)

def main() raises:
    var first: List[Int] = [11]
    var second: List[Int] = [22]
    var third: List[Int] = [33]
    var fourth: List[Int] = [44]
    exercise(first, second, third, fourth)
