"""Every Result transformation forwards through two native generic layers."""
from fp.algebra import map, flat_map, ResultFamily
from fp.data import Result, Ok, Err
from std.testing import assert_equal, assert_true
from std.memory import ArcPointer

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
struct Value(Movable):
    var number: Int
@fieldwise_init
struct Domain(Movable):
    var code: Int
@fieldwise_init
struct Output(Movable):
    var text: String
@fieldwise_init
struct Translated(Movable):
    var code: Int
@fieldwise_init
struct Fault(Movable):
    var code: Int

def value_number(value: Value) -> Int: return value.number
def domain_code(error: Domain) -> Int: return -error.code
def output_number(value: Output) -> Int: return value.text.byte_length()
def translated_code(error: Translated) -> Int: return -error.code

# The pure and explicitly Never paths can be called without a try boundary.
def stringify(var value: Value) -> Output: return Output(String(value.number))
def translate(var error: Domain) -> Translated: return Translated(error.code + 10)
def bind(var value: Value) -> Result[Output, Domain]: return Result[Output, Domain](Ok(Output(String(value.number))))
def recover(var error: Domain) -> Result[Value, Translated]: return Result[Value, Translated](Err(Translated(error.code + 10)))
def stringify_never(var value: Value) raises Never -> Output: return Output(String(value.number))
def translate_never(var error: Domain) raises Never -> Translated: return Translated(error.code + 10)
def bind_never(var value: Value) raises Never -> Result[Output, Domain]: return Result[Output, Domain](Ok(Output(String(value.number))))
def recover_never(var error: Domain) raises Never -> Result[Value, Translated]: return Result[Value, Translated](Err(Translated(error.code + 10)))

def pure_paths() -> Int:
    var m = map_pure2(Result[Value, Domain](Ok(Value(123))), stringify)
    var e = map_err_pure2(Result[Value, Domain](Err(Domain(7))), translate)
    var b = and_then_pure2(Result[Value, Domain](Ok(Value(123))), bind)
    var r = or_else_pure2(Result[Value, Domain](Err(Domain(7))), recover)
    var mn = map_raising2[X=Never](Result[Value, Domain](Ok(Value(123))), stringify_never)
    var en = map_err_raising2[X=Never](Result[Value, Domain](Err(Domain(7))), translate_never)
    var bn = and_then_raising2[X=Never](Result[Value, Domain](Ok(Value(123))), bind_never)
    var rn = or_else_raising2[X=Never](Result[Value, Domain](Err(Domain(7))), recover_never)
    return m.fold(output_number, domain_code) + e.fold(value_number, translated_code) + b.fold(output_number, domain_code) + r.fold(value_number, translated_code) + mn.fold(output_number, domain_code) + en.fold(value_number, translated_code) + bn.fold(output_number, domain_code) + rn.fold(value_number, translated_code)

# The expected cases below are an explicit branch table, independent of Result folds.
def exercise(operation: Int, active_ok: Bool, mode: Int, calls: ArcPointer[Int]) -> Int:
    def mapped(var value: Value) raises Fault {calls, mode} -> Output:
        calls[] += 1
        if mode == 2: raise Fault(value.number + 100)
        return Output(String(value.number))
    def changed(var error: Domain) raises Fault {calls, mode} -> Translated:
        calls[] += 1
        if mode == 2: raise Fault(error.code + 200)
        return Translated(error.code + 10)
    def bound(var value: Value) raises Fault {calls, mode} -> Result[Output, Domain]:
        calls[] += 1
        if mode == 2: raise Fault(value.number + 300)
        if mode == 1: return Result[Output, Domain](Err(Domain(31)))
        return Result[Output, Domain](Ok(Output(String(value.number))))
    def recovered(var error: Domain) raises Fault {calls, mode} -> Result[Value, Translated]:
        calls[] += 1
        if mode == 2: raise Fault(error.code + 400)
        if mode == 1: return Result[Value, Translated](Err(Translated(41)))
        return Result[Value, Translated](Ok(Value(error.code * 10)))
    var value = Result[Value, Domain](Ok(Value(123))) if active_ok else Result[Value, Domain](Err(Domain(7)))
    try:
        if operation == 0:
            var result = map_raising2(value^, mapped)
            return result.fold(output_number, domain_code)
        if operation == 1:
            var result = map_err_raising2(value^, changed)
            return result.fold(value_number, translated_code)
        if operation == 2:
            var result = and_then_raising2(value^, bound)
            return result.fold(output_number, domain_code)
        var result = or_else_raising2(value^, recovered)
        return result.fold(value_number, translated_code)
    except error:
        comptime assert type_of(error) == Fault
        return -1000 - error.code

def stop(var value: Int) raises StopIteration -> Int: raise StopIteration()
def stop_bind(var value: Int) raises StopIteration -> Result[Int, Int]: raise StopIteration()
def same_error(var value: Int) raises Int -> Result[Int, Int]:
    if value == 0: return Result[Int, Int](Err(17))
    raise 17

def number(value: Int) -> Int: return value
def negative(value: Int) -> Int: return -value

def main() raises:
    assert_equal(pure_paths(), -56)
    for operation in range(4):
        for active_ok in range(2):
            for mode in range(3):
                var calls = ArcPointer(0)
                var actual = exercise(operation, Bool(active_ok), mode, calls)
                var active = Bool(active_ok) if operation == 0 or operation == 2 else not Bool(active_ok)
                var expected: Int
                if not active: expected = 123 if active_ok else -7
                elif mode == 2:
                    expected = -1223 if operation == 0 else -1207 if operation == 1 else -1423 if operation == 2 else -1407
                elif operation == 0: expected = 3
                elif operation == 1: expected = -17
                elif operation == 2: expected = -31 if mode == 1 else 3
                else: expected = -41 if mode == 1 else 70
                assert_equal(actual, expected)
                assert_equal(calls[], 1 if active else 0)
    for operation in range(4):
        for active in range(2):
            var source = Result[Int, Int](Ok(0)) if Bool(active) == (operation < 2) else Result[Int, Int](Err(0))
            var caught = False
            try:
                if operation == 0: _ = map_raising2(source^, stop)
                elif operation == 1: _ = and_then_raising2(source^, stop_bind)
                elif operation == 2: _ = map_err_raising2(source^, stop)
                else: _ = or_else_raising2(source^, stop_bind)
            except error:
                comptime assert type_of(error) == StopIteration
                caught = True
            assert_equal(caught, Bool(active))
    # An Err payload is not a thrown callback error even when their native type is identical.
    for operation in range(2):
        for should_raise in range(2):
            var source = Result[Int, Int](Ok(should_raise)) if operation == 0 else Result[Int, Int](Err(should_raise))
            var caught = False
            var encoded: Int
            try:
                var output = and_then_raising2(source^, same_error) if operation == 0 else or_else_raising2(source^, same_error)
                encoded = output.fold(number, negative)
            except error:
                comptime assert type_of(error) == Int
                encoded = error
                caught = True
            assert_equal(caught, Bool(should_raise))
            assert_equal(encoded, 17 if should_raise else -17)
