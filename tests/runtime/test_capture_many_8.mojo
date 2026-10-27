from fp.data import Capture, Result
from std.testing import assert_equal

def pure_value(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int, var a5: Int, var a6: Int, var a7: Int) -> Int: return a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7
def pure_void(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int, var a5: Int, var a6: Int, var a7: Int): pass
def never_value(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int, var a5: Int, var a6: Int, var a7: Int) raises Never -> Int: return a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7
def never_void(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int, var a5: Int, var a6: Int, var a7: Int) raises Never: pass
def error_value(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int, var a5: Int, var a6: Int, var a7: Int) raises Int -> Int: raise a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7
def error_void(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int, var a5: Int, var a6: Int, var a7: Int) raises Int: raise a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7

def main() raises:
    var pure_value_result = Capture[Int].args(1, 2, 3, 4, 5, 6, 7, 8).run(pure_value)
    comptime assert type_of(pure_value_result) == Result[Int, Never]
    assert_equal(pure_value_result._ok().value, 36)
    var pure_void_result = Capture[Int].args(1, 2, 3, 4, 5, 6, 7, 8).run(pure_void)
    comptime assert type_of(pure_void_result) == Result[type_of(None), Never]
    assert_equal(pure_void_result.is_ok(), True)
    var never_value_result = Capture[Int].args(1, 2, 3, 4, 5, 6, 7, 8).run(never_value)
    comptime assert type_of(never_value_result) == Result[Int, Never]
    assert_equal(never_value_result._ok().value, 36)
    var never_void_result = Capture[Int].args(1, 2, 3, 4, 5, 6, 7, 8).run(never_void)
    comptime assert type_of(never_void_result) == Result[type_of(None), Never]
    assert_equal(never_void_result.is_ok(), True)
    var error_value_result = Capture[Int].args(1, 2, 3, 4, 5, 6, 7, 8).run(error_value)
    comptime assert type_of(error_value_result) == Result[Int, Int]
    assert_equal(error_value_result._err().value, 36)
    var error_void_result = Capture[Int].args(1, 2, 3, 4, 5, 6, 7, 8).run(error_void)
    comptime assert type_of(error_void_result) == Result[type_of(None), Int]
    assert_equal(error_void_result._err().value, 36)
    var calls = 0
    def captured_pure_value(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int, var a5: Int, var a6: Int, var a7: Int) {mut calls} -> Int:
        calls += 1
        return a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7
    var captured_pure_value_result = Capture[Int].args(1, 2, 3, 4, 5, 6, 7, 8).run(captured_pure_value)
    assert_equal(captured_pure_value_result._ok().value, 36)
    def captured_pure_void(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int, var a5: Int, var a6: Int, var a7: Int) {mut calls}:
        calls += 1
        pass
    var captured_pure_void_result = Capture[Int].args(1, 2, 3, 4, 5, 6, 7, 8).run(captured_pure_void)
    assert_equal(captured_pure_void_result.is_ok(), True)
    def captured_never_value(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int, var a5: Int, var a6: Int, var a7: Int) raises Never {mut calls} -> Int:
        calls += 1
        return a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7
    var captured_never_value_result = Capture[Int].args(1, 2, 3, 4, 5, 6, 7, 8).run(captured_never_value)
    assert_equal(captured_never_value_result._ok().value, 36)
    def captured_never_void(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int, var a5: Int, var a6: Int, var a7: Int) raises Never {mut calls}:
        calls += 1
        pass
    var captured_never_void_result = Capture[Int].args(1, 2, 3, 4, 5, 6, 7, 8).run(captured_never_void)
    assert_equal(captured_never_void_result.is_ok(), True)
    def captured_error_value(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int, var a5: Int, var a6: Int, var a7: Int) raises Int {mut calls} -> Int:
        calls += 1
        raise a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7
    var captured_error_value_result = Capture[Int].args(1, 2, 3, 4, 5, 6, 7, 8).run(captured_error_value)
    assert_equal(captured_error_value_result._err().value, 36)
    def captured_error_void(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int, var a5: Int, var a6: Int, var a7: Int) raises Int {mut calls}:
        calls += 1
        raise a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7
    var captured_error_void_result = Capture[Int].args(1, 2, 3, 4, 5, 6, 7, 8).run(captured_error_void)
    assert_equal(captured_error_void_result._err().value, 36)
    assert_equal(calls, 6)
    assert_equal(Capture[Int].args(1, 2).take(3).take(4).take(5).take(6).take(7).take(8).run(pure_value)._ok().value, 36)
    var pointer: def(var a0: Int, var a1: Int, var a2: Int, var a3: Int, var a4: Int, var a5: Int, var a6: Int, var a7: Int) raises Int thin -> Int = error_value
    assert_equal(Capture[Int].args(1, 2, 3, 4, 5, 6, 7, 8).run(pointer)._err().value, 36)
