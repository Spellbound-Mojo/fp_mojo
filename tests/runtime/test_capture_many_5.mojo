from fp.data import Capture, Result
from std.testing import assert_equal

def pure_value(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int) -> Int: return a0 + a1 + a2 + a3 + a4
def pure_void(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int): pass
def never_value(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int) raises Never -> Int: return a0 + a1 + a2 + a3 + a4
def never_void(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int) raises Never: pass
def error_value(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int) raises Int -> Int: raise a0 + a1 + a2 + a3 + a4
def error_void(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int) raises Int: raise a0 + a1 + a2 + a3 + a4

def main() raises:
    var pure_value_result = Capture[Int].args(1, 2, 3, 4, 5).run(pure_value)
    comptime assert type_of(pure_value_result) == Result[Int, Never]
    assert_equal(pure_value_result._ok().value, 15)
    var pure_void_result = Capture[Int].args(1, 2, 3, 4, 5).run(pure_void)
    comptime assert type_of(pure_void_result) == Result[type_of(None), Never]
    assert_equal(pure_void_result.is_ok(), True)
    var never_value_result = Capture[Int].args(1, 2, 3, 4, 5).run(never_value)
    comptime assert type_of(never_value_result) == Result[Int, Never]
    assert_equal(never_value_result._ok().value, 15)
    var never_void_result = Capture[Int].args(1, 2, 3, 4, 5).run(never_void)
    comptime assert type_of(never_void_result) == Result[type_of(None), Never]
    assert_equal(never_void_result.is_ok(), True)
    var error_value_result = Capture[Int].args(1, 2, 3, 4, 5).run(error_value)
    comptime assert type_of(error_value_result) == Result[Int, Int]
    assert_equal(error_value_result._err().value, 15)
    var error_void_result = Capture[Int].args(1, 2, 3, 4, 5).run(error_void)
    comptime assert type_of(error_void_result) == Result[type_of(None), Int]
    assert_equal(error_void_result._err().value, 15)
    var calls = 0
    def captured_pure_value(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int) {mut calls} -> Int:
        calls += 1
        return a0 + a1 + a2 + a3 + a4
    var captured_pure_value_result = Capture[Int].args(1, 2, 3, 4, 5).run(captured_pure_value)
    assert_equal(captured_pure_value_result._ok().value, 15)
    def captured_pure_void(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int) {mut calls}:
        calls += 1
        pass
    var captured_pure_void_result = Capture[Int].args(1, 2, 3, 4, 5).run(captured_pure_void)
    assert_equal(captured_pure_void_result.is_ok(), True)
    def captured_never_value(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int) raises Never {mut calls} -> Int:
        calls += 1
        return a0 + a1 + a2 + a3 + a4
    var captured_never_value_result = Capture[Int].args(1, 2, 3, 4, 5).run(captured_never_value)
    assert_equal(captured_never_value_result._ok().value, 15)
    def captured_never_void(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int) raises Never {mut calls}:
        calls += 1
        pass
    var captured_never_void_result = Capture[Int].args(1, 2, 3, 4, 5).run(captured_never_void)
    assert_equal(captured_never_void_result.is_ok(), True)
    def captured_error_value(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int) raises Int {mut calls} -> Int:
        calls += 1
        raise a0 + a1 + a2 + a3 + a4
    var captured_error_value_result = Capture[Int].args(1, 2, 3, 4, 5).run(captured_error_value)
    assert_equal(captured_error_value_result._err().value, 15)
    def captured_error_void(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int) raises Int {mut calls}:
        calls += 1
        raise a0 + a1 + a2 + a3 + a4
    var captured_error_void_result = Capture[Int].args(1, 2, 3, 4, 5).run(captured_error_void)
    assert_equal(captured_error_void_result._err().value, 15)
    assert_equal(calls, 6)
    assert_equal(Capture[Int].args(1, 2).take(3).take(4).take(5).run(pure_value)._ok().value, 15)
    var pointer: def(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int) raises Int thin -> Int = error_value
    assert_equal(Capture[Int].args(1, 2, 3, 4, 5).run(pointer)._err().value, 15)
