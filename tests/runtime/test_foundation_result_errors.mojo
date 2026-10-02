"""Changing payload types and distinguishing a native error from a same-type Err."""
from fp.algebra import map, flat_map, ResultFamily
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.utils import Variant
from std.testing import assert_equal

def read(value: Int) -> Int:
    return value

def negative(value: Int) -> Int:
    return -value

def owned(var value: Int) -> Int:
    return value

def owned_error(var value: Int) -> Int:
    return -value

def exercise(operation: Int, ok: Bool, calls: ArcPointer[Int]) -> Int:
    def fail(var value: Int) raises Int {calls} -> Int:
        calls[] += 1
        raise value + 100
    def fail_bind(var value: Int) raises Int {calls} -> Result[Int, Int]:
        calls[] += 1
        raise value + 100
    def fail_borrow(value: Int) raises Int {calls} -> Int:
        calls[] += 1
        raise value + 100
    var input = Result[Int, Int](Ok(7)) if ok else Result[Int, Int](Err(7))
    try:
        var output: Result[Int, Int]
        if operation == 0: output = map[ResultFamily[type_of(input).Error]](fail, input^)
        elif operation == 1: output = flat_map[ResultFamily[type_of(input).Error]](fail_bind, input^)
        elif operation == 2: output = input^.map_err(fail)
        elif operation == 3: output = input^.or_else(fail_bind)
        elif operation == 4: return input.fold(fail_borrow, negative)
        else: return input^.fold_owned(fail, owned_error)
        return output.fold(read, negative)
    except error:
        comptime assert type_of(error) == Int
        return -1000 - error

def stringify(var value: Int) raises String -> String:
    return String(value)

def length(var value: String) raises String -> Int:
    return value.byte_length()

def bind(var value: String) raises String -> Result[Int, Int]:
    return Result[Int, Int](Ok(value.byte_length()))

def recover(var error: Int) raises String -> Result[Int, String]:
    return Result[Int, String](Ok(error * 10))

def read_error(value: String) -> Int:
    return -value.byte_length()

comptime CommonError = Variant[Int, String]

def mapped_number(value: Int) raises CommonError -> Int:
    raise CommonError(value)

def mapped_text(value: Int) raises CommonError -> Int:
    raise CommonError(String(value))

def explicit_common(ok: Bool) -> Int:
    var value = Result[Int, Int](Ok(123)) if ok else Result[Int, Int](Err(123))
    try:
        return value.fold(mapped_number, mapped_text)
    except error:
        comptime assert type_of(error) == CommonError
        if error.isa[Int](): return error^.unwrap[Int]()
        return error^.unwrap[String]().byte_length()


def main() raises:
    assert_equal(explicit_common(True), 123)
    assert_equal(explicit_common(False), 3)
    for operation in range(6):
        for ok in range(2):
            var calls = ArcPointer(0)
            var active = not Bool(ok) if operation == 2 or operation == 3 else Bool(ok)
            assert_equal(exercise(operation, Bool(ok), calls), -1107 if active else 7 if ok else -7)
            assert_equal(calls[], 1 if active else 0)
    for ok in range(2):
        var input = Result[Int, String](Ok(123)) if ok else Result[Int, String](Err(String("error")))
        # Every operation changes an actual success/error payload type.
        var mapped = map[ResultFamily[type_of(input).Error]](stringify, input^)
        var remapped = mapped^.map_err(length)
        var bound = flat_map[ResultFamily[type_of(remapped).Error]](bind, remapped^)
        var recovered = bound^.or_else(recover)
        assert_equal(recovered.fold(read, read_error), 3 if ok else 50)
