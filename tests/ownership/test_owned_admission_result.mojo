"""Every Result adapter retains native payload, result and error origins."""
from fp.algebra import map, flat_map, ResultFamily
from fp.data import Result, Ok, Err
from std.testing import assert_equal, assert_true

def copied[V: Copyable & Deinitable](value: V) -> V: return value.copy()
def moved[V: Movable & Deinitable](var value: V) -> V: return value^
def copied_never[V: Copyable & Deinitable](value: V) raises Never -> V: return value.copy()
def moved_never[V: Movable & Deinitable](var value: V) raises Never -> V: return value^
def copied_raising[V: Copyable & Deinitable](value: V) raises V -> V: return value.copy()
def moved_raising[V: Movable & Deinitable](var value: V) raises V -> V: return value^
def fail_borrow[V: Copyable & Deinitable](value: V) raises V -> V: raise value.copy()
def fail_owned[V: Movable & Deinitable](var value: V) raises V -> V: raise value^
def keep[V: Movable & Deinitable](var value: V) -> Result[V, V]: return Result[V, V](Ok(value^))
def recover[V: Movable & Deinitable](var value: V) -> Result[V, V]: return Result[V, V](Err(value^))
def keep_raising[V: Movable & Deinitable](var value: V) raises V -> Result[V, V]: return Result[V, V](Ok(value^))
def recover_raising[V: Movable & Deinitable](var value: V) raises V -> Result[V, V]: return Result[V, V](Err(value^))

def fold_forward[T: Movable & Deinitable, E: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: def(var T) raises X -> R, G: def(var E) -> R](var value: Result[T, E], f: F, g: G) raises X -> R:
    return value^.fold_owned[R=R, X=X](f, g)

def exercise[V: Copyable & Deinitable, F: def(V) -> Int](value: V, check: F, expected: Int) raises V:
    for active in range(2):
        var subject = Result[V, V](Ok(value.copy())) if active else Result[V, V](Err(value.copy()))
        debug_assert[assert_mode="safe"](check(subject.fold(copied[V], copied[V])) == expected, "origin changed")
        debug_assert[assert_mode="safe"](check(subject.fold(copied_raising[V], copied[V])) == expected, "origin changed")
        debug_assert[assert_mode="safe"](check(subject.fold(copied[V], copied_raising[V])) == expected, "origin changed")
        debug_assert[assert_mode="safe"](check(subject.fold(copied_raising[V], copied_raising[V])) == expected, "origin changed")
        debug_assert[assert_mode="safe"](check(subject.copy().fold_owned(moved[V], moved[V])) == expected, "origin changed")
        debug_assert[assert_mode="safe"](check(subject.copy().fold_owned(moved_raising[V], moved[V])) == expected, "origin changed")
        debug_assert[assert_mode="safe"](check(subject.copy().fold_owned(moved[V], moved_raising[V])) == expected, "origin changed")
        debug_assert[assert_mode="safe"](check(subject.copy().fold_owned(moved_raising[V], moved_raising[V])) == expected, "origin changed")
        debug_assert[assert_mode="safe"](check(fold_forward(subject.copy(), moved_raising[V], moved[V])) == expected, "origin changed")
        try:
            debug_assert[assert_mode="safe"](check(subject.fold(copied_never[V], copied_raising[V])) == expected, "Never changed origins")
        except:
            debug_assert[assert_mode="safe"](False, "unexpected error from Never control")
        try:
            debug_assert[assert_mode="safe"](check(subject.fold(copied_raising[V], copied_never[V])) == expected, "Never changed origins")
        except:
            debug_assert[assert_mode="safe"](False, "unexpected error from Never control")
        debug_assert[assert_mode="safe"](check(subject.fold(copied_never[V], copied_never[V])) == expected, "Never changed origins")
        try:
            debug_assert[assert_mode="safe"](check(subject.copy().fold_owned(moved_never[V], moved_raising[V])) == expected, "Never changed origins")
        except:
            debug_assert[assert_mode="safe"](False, "unexpected error from Never control")
        try:
            debug_assert[assert_mode="safe"](check(subject.copy().fold_owned(moved_raising[V], moved_never[V])) == expected, "Never changed origins")
        except:
            debug_assert[assert_mode="safe"](False, "unexpected error from Never control")
        debug_assert[assert_mode="safe"](check(subject.copy().fold_owned(moved_never[V], moved_never[V])) == expected, "Never changed origins")
        var failures = 0
        try: _ = subject.fold(fail_borrow[V], fail_borrow[V])
        except error:
            failures += 1
            debug_assert[assert_mode="safe"](check(error) == expected, "error origin changed")
        try: _ = subject.copy().fold_owned(fail_owned[V], fail_owned[V])
        except error:
            failures += 1
            debug_assert[assert_mode="safe"](check(error) == expected, "error origin changed")
        debug_assert[assert_mode="safe"](failures == 2, "wrong exception count")
        var r1 = map[ResultFamily[type_of(subject.copy()).Error]](moved[V], subject.copy())
        var r2 = map[ResultFamily[type_of(subject.copy()).Error]](moved_raising[V], subject.copy())
        var r3 = subject.copy().map_err(moved[V])
        var r4 = subject.copy().map_err(moved_raising[V])
        var r5 = flat_map[ResultFamily[type_of(subject.copy()).Error]](keep[V], subject.copy())
        var r6 = flat_map[ResultFamily[type_of(subject.copy()).Error]](keep_raising[V], subject.copy())
        var r7 = subject.copy().or_else(recover[V])
        var r8 = subject.copy().or_else(recover_raising[V])
        debug_assert[assert_mode="safe"](check(r1.fold(copied[V], copied[V])) == expected, "origin changed")
        debug_assert[assert_mode="safe"](check(r2.fold(copied[V], copied[V])) == expected, "origin changed")
        debug_assert[assert_mode="safe"](check(r3.fold(copied[V], copied[V])) == expected, "origin changed")
        debug_assert[assert_mode="safe"](check(r4.fold(copied[V], copied[V])) == expected, "origin changed")
        debug_assert[assert_mode="safe"](check(r5.fold(copied[V], copied[V])) == expected, "origin changed")
        debug_assert[assert_mode="safe"](check(r6.fold(copied[V], copied[V])) == expected, "origin changed")
        debug_assert[assert_mode="safe"](check(r7.fold(copied[V], copied[V])) == expected, "origin changed")
        debug_assert[assert_mode="safe"](check(r8.fold(copied[V], copied[V])) == expected, "origin changed")
        debug_assert[assert_mode="safe"](r1.is_ok() == Bool(active), "map changed constructor")
        debug_assert[assert_mode="safe"](r8.is_ok() == Bool(active), "or_else changed constructor")

def owners(first: List[Int], second: List[Int]) raises:
    var a = Span(first)
    var b = Span(second)
    comptime A = type_of(a)
    comptime B = type_of(b)
    def left(value: A) -> Int: return value[0]
    def right(value: B) -> Int: return value[0]
    try: exercise(a, left, 11)
    except: raise Error("unexpected left error")
    try: exercise(b, right, 22)
    except: raise Error("unexpected right error")
    assert_true(Pointer(to=a[0]) != Pointer(to=b[0]))

def main() raises:
    var first: List[Int] = [11]
    var second: List[Int] = [22]
    owners(first, second)
