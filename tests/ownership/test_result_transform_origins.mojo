"""Four argument-carried native origins survive every transformation and error route."""
from fp.algebra import map, flat_map, ResultFamily
from fp.data import Result, Ok, Err
from std.testing import assert_equal, assert_true

def map_pure1[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, //, F: def(var T) -> U](var value: Result[T, E], callback: F) -> Result[U, E]:
    return map[ResultFamily[type_of(value).Error]](callback, value^)

def map_pure2[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, //, F: def(var T) -> U](var value: Result[T, E], callback: F) -> Result[U, E]:
    return map_pure1(value^, callback)

def map_raising1[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var T) raises X -> U](var value: Result[T, E], callback: F) raises X -> Result[U, E]:
    return map[ResultFamily[type_of(value).Error], X=X](callback, value^)

def map_raising2[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var T) raises X -> U](var value: Result[T, E], callback: F) raises X -> Result[U, E]:
    return map_raising1[X=X](value^, callback)

def map_err_pure1[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, //, F: def(var E) -> U](var value: Result[T, E], callback: F) -> Result[T, U]:
    return value^.map_err(callback)

def map_err_pure2[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, //, F: def(var E) -> U](var value: Result[T, E], callback: F) -> Result[T, U]:
    return map_err_pure1(value^, callback)

def map_err_raising1[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var E) raises X -> U](var value: Result[T, E], callback: F) raises X -> Result[T, U]:
    return value^.map_err[X=X](callback)

def map_err_raising2[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var E) raises X -> U](var value: Result[T, E], callback: F) raises X -> Result[T, U]:
    return map_err_raising1[X=X](value^, callback)

def and_then_pure1[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, //, F: def(var T) -> Result[U, E]](var value: Result[T, E], callback: F) -> Result[U, E]:
    return flat_map[ResultFamily[type_of(value).Error]](callback, value^)

def and_then_pure2[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, //, F: def(var T) -> Result[U, E]](var value: Result[T, E], callback: F) -> Result[U, E]:
    return and_then_pure1(value^, callback)

def and_then_raising1[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var T) raises X -> Result[U, E]](var value: Result[T, E], callback: F) raises X -> Result[U, E]:
    return flat_map[ResultFamily[type_of(value).Error], X=X](callback, value^)

def and_then_raising2[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var T) raises X -> Result[U, E]](var value: Result[T, E], callback: F) raises X -> Result[U, E]:
    return and_then_raising1[X=X](value^, callback)

def or_else_pure1[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, //, F: def(var E) -> Result[T, U]](var value: Result[T, E], callback: F) -> Result[T, U]:
    return value^.or_else(callback)

def or_else_pure2[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, //, F: def(var E) -> Result[T, U]](var value: Result[T, E], callback: F) -> Result[T, U]:
    return or_else_pure1(value^, callback)

def or_else_raising1[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var E) raises X -> Result[T, U]](var value: Result[T, E], callback: F) raises X -> Result[T, U]:
    return value^.or_else[X=X](callback)

def or_else_raising2[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var E) raises X -> Result[T, U]](var value: Result[T, E], callback: F) raises X -> Result[T, U]:
    return or_else_raising1[X=X](value^, callback)

@fieldwise_init
struct Packet[V: Copyable & Deinitable, Other: Copyable & Deinitable,
              U: Copyable & Deinitable, X: Copyable & Deinitable](Copyable):
    var view: Self.V
    var other: Self.Other
    var output: Self.U
    var failure: Self.X
    var mode: Int

def mapped[V: Copyable & Deinitable, O: Copyable & Deinitable, U: Copyable & Deinitable, X: Copyable & Deinitable](var value: Packet[V, O, U, X]) -> U:
    return value.output.copy()
def mapped_raising[V: Copyable & Deinitable, O: Copyable & Deinitable, U: Copyable & Deinitable, X: Copyable & Deinitable](var value: Packet[V, O, U, X]) raises X -> U:
    if value.mode == 2: raise value.failure.copy()
    return value.output.copy()
def bound[V: Copyable & Deinitable, O: Copyable & Deinitable, U: Copyable & Deinitable, X: Copyable & Deinitable](var value: Packet[V, O, U, X]) -> Result[U, O]:
    if value.mode == 1: return Result[U, O](Err(value.other.copy()))
    return Result[U, O](Ok(value.output.copy()))
def bound_raising[V: Copyable & Deinitable, O: Copyable & Deinitable, U: Copyable & Deinitable, X: Copyable & Deinitable](var value: Packet[V, O, U, X]) raises X -> Result[U, O]:
    if value.mode == 2: raise value.failure.copy()
    if value.mode == 1: return Result[U, O](Err(value.other.copy()))
    return Result[U, O](Ok(value.output.copy()))
def recovered[V: Copyable & Deinitable, O: Copyable & Deinitable, U: Copyable & Deinitable, X: Copyable & Deinitable](var value: Packet[V, O, U, X]) -> Result[O, U]:
    if value.mode == 1: return Result[O, U](Err(value.output.copy()))
    return Result[O, U](Ok(value.other.copy()))
def recovered_raising[V: Copyable & Deinitable, O: Copyable & Deinitable, U: Copyable & Deinitable, X: Copyable & Deinitable](var value: Packet[V, O, U, X]) raises X -> Result[O, U]:
    if value.mode == 2: raise value.failure.copy()
    if value.mode == 1: return Result[O, U](Err(value.output.copy()))
    return Result[O, U](Ok(value.other.copy()))

def exercise(first: List[Int], second: List[Int], third: List[Int], fourth: List[Int]) raises:
    var a = Span(first)
    var b = Span(second)
    var c = Span(third)
    var d = Span(fourth)
    comptime A = type_of(a)
    comptime B = type_of(b)
    comptime C = type_of(c)
    comptime D = type_of(d)
    comptime P = Packet[A, B, C, D]
    comptime Q = Packet[B, A, C, D]
    # Return pointer identity, not just equal contents, for each original owner.
    for active in range(2):
        for mode in range(3):
            var p = P(a, b, c, d, mode)
            var q = Q(b, a, c, d, mode)
            var subject_map_pure = Result[P, B](Ok(p.copy())) if active else Result[P, B](Err(b))
            var result_map_pure = map_pure2(subject_map_pure^, mapped[A, B, C, D])
            try:
                var value = result_map_pure^.raise_on_err()
                debug_assert[assert_mode="safe"](Pointer(to=value[0]) == Pointer(to=third[0]))
                debug_assert[assert_mode="safe"](Bool(active))
            except error:
                comptime assert type_of(error) == B
                debug_assert[assert_mode="safe"](Pointer(to=error[0]) == Pointer(to=second[0]))
                debug_assert[assert_mode="safe"](not (Bool(active)))
            var subject_map_err_pure = Result[A, Q](Err(q.copy())) if active else Result[A, Q](Ok(a))
            var result_map_err_pure = map_err_pure2(subject_map_err_pure^, mapped[B, A, C, D])
            try:
                var value = result_map_err_pure^.raise_on_err()
                debug_assert[assert_mode="safe"](Pointer(to=value[0]) == Pointer(to=first[0]))
                debug_assert[assert_mode="safe"](not Bool(active))
            except error:
                comptime assert type_of(error) == C
                debug_assert[assert_mode="safe"](Pointer(to=error[0]) == Pointer(to=third[0]))
                debug_assert[assert_mode="safe"](not (not Bool(active)))
            var subject_and_then_pure = Result[P, B](Ok(p.copy())) if active else Result[P, B](Err(b))
            var result_and_then_pure = and_then_pure2(subject_and_then_pure^, bound[A, B, C, D])
            try:
                var value = result_and_then_pure^.raise_on_err()
                debug_assert[assert_mode="safe"](Pointer(to=value[0]) == Pointer(to=third[0]))
                debug_assert[assert_mode="safe"](Bool(active) and mode != 1)
            except error:
                comptime assert type_of(error) == B
                debug_assert[assert_mode="safe"](Pointer(to=error[0]) == Pointer(to=second[0]))
                debug_assert[assert_mode="safe"](not (Bool(active) and mode != 1))
            var subject_or_else_pure = Result[A, Q](Err(q.copy())) if active else Result[A, Q](Ok(a))
            var result_or_else_pure = or_else_pure2(subject_or_else_pure^, recovered[B, A, C, D])
            try:
                var value = result_or_else_pure^.raise_on_err()
                debug_assert[assert_mode="safe"](Pointer(to=value[0]) == Pointer(to=first[0]))
                debug_assert[assert_mode="safe"](not Bool(active) or mode != 1)
            except error:
                comptime assert type_of(error) == C
                debug_assert[assert_mode="safe"](Pointer(to=error[0]) == Pointer(to=third[0]))
                debug_assert[assert_mode="safe"](not (not Bool(active) or mode != 1))
            var subject_map_raising = Result[P, B](Ok(p.copy())) if active else Result[P, B](Err(b))
            var caught_map_raising = False
            try:
                var result_map_raising = map_raising2(subject_map_raising^, mapped_raising[A, B, C, D])
                try:
                    var value = result_map_raising^.raise_on_err()
                    debug_assert[assert_mode="safe"](Pointer(to=value[0]) == Pointer(to=third[0]))
                    debug_assert[assert_mode="safe"](Bool(active))
                except error:
                    comptime assert type_of(error) == B
                    debug_assert[assert_mode="safe"](Pointer(to=error[0]) == Pointer(to=second[0]))
                    debug_assert[assert_mode="safe"](not (Bool(active)))
            except error:
                comptime assert type_of(error) == D
                assert_true(Pointer(to=error[0]) == Pointer(to=fourth[0]))
                caught_map_raising = True
            assert_equal(caught_map_raising, Bool(active) and mode == 2)
            var subject_map_err_raising = Result[A, Q](Err(q.copy())) if active else Result[A, Q](Ok(a))
            var caught_map_err_raising = False
            try:
                var result_map_err_raising = map_err_raising2(subject_map_err_raising^, mapped_raising[B, A, C, D])
                try:
                    var value = result_map_err_raising^.raise_on_err()
                    debug_assert[assert_mode="safe"](Pointer(to=value[0]) == Pointer(to=first[0]))
                    debug_assert[assert_mode="safe"](not Bool(active))
                except error:
                    comptime assert type_of(error) == C
                    debug_assert[assert_mode="safe"](Pointer(to=error[0]) == Pointer(to=third[0]))
                    debug_assert[assert_mode="safe"](not (not Bool(active)))
            except error:
                comptime assert type_of(error) == D
                assert_true(Pointer(to=error[0]) == Pointer(to=fourth[0]))
                caught_map_err_raising = True
            assert_equal(caught_map_err_raising, Bool(active) and mode == 2)
            var subject_and_then_raising = Result[P, B](Ok(p.copy())) if active else Result[P, B](Err(b))
            var caught_and_then_raising = False
            try:
                var result_and_then_raising = and_then_raising2(subject_and_then_raising^, bound_raising[A, B, C, D])
                try:
                    var value = result_and_then_raising^.raise_on_err()
                    debug_assert[assert_mode="safe"](Pointer(to=value[0]) == Pointer(to=third[0]))
                    debug_assert[assert_mode="safe"](Bool(active) and mode != 1)
                except error:
                    comptime assert type_of(error) == B
                    debug_assert[assert_mode="safe"](Pointer(to=error[0]) == Pointer(to=second[0]))
                    debug_assert[assert_mode="safe"](not (Bool(active) and mode != 1))
            except error:
                comptime assert type_of(error) == D
                assert_true(Pointer(to=error[0]) == Pointer(to=fourth[0]))
                caught_and_then_raising = True
            assert_equal(caught_and_then_raising, Bool(active) and mode == 2)
            var subject_or_else_raising = Result[A, Q](Err(q.copy())) if active else Result[A, Q](Ok(a))
            var caught_or_else_raising = False
            try:
                var result_or_else_raising = or_else_raising2(subject_or_else_raising^, recovered_raising[B, A, C, D])
                try:
                    var value = result_or_else_raising^.raise_on_err()
                    debug_assert[assert_mode="safe"](Pointer(to=value[0]) == Pointer(to=first[0]))
                    debug_assert[assert_mode="safe"](not Bool(active) or mode != 1)
                except error:
                    comptime assert type_of(error) == C
                    debug_assert[assert_mode="safe"](Pointer(to=error[0]) == Pointer(to=third[0]))
                    debug_assert[assert_mode="safe"](not (not Bool(active) or mode != 1))
            except error:
                comptime assert type_of(error) == D
                assert_true(Pointer(to=error[0]) == Pointer(to=fourth[0]))
                caught_or_else_raising = True
            assert_equal(caught_or_else_raising, Bool(active) and mode == 2)
    assert_equal(a[0] + b[0] + c[0] + d[0], 110)

def main() raises:
    var first: List[Int] = [11]
    var second: List[Int] = [22]
    var third: List[Int] = [33]
    var fourth: List[Int] = [44]
    exercise(first, second, third, fourth)
