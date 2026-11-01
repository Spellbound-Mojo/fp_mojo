"""Bind three native conventions before matching a reusable callback."""
from fp.data import Capture
from std.testing import assert_equal


def rmo(prefix: String, mut state: String, var suffix: String) -> String:
    state += suffix
    return prefix + state

def rom(prefix: String, var suffix: String, mut state: String) -> String:
    return rmo(prefix, state, suffix^)

def mro(mut state: String, prefix: String, var suffix: String) -> String:
    return rmo(prefix, state, suffix^)

def mor(mut state: String, var suffix: String, prefix: String) -> String:
    return rmo(prefix, state, suffix^)

def orm(var suffix: String, prefix: String, mut state: String) -> String:
    return rmo(prefix, state, suffix^)

def omr(var suffix: String, mut state: String, prefix: String) -> String:
    return rmo(prefix, state, suffix^)


def check_orders() raises:
    var prefix = String("prefix:")
    var state = String("old")
    comptime CaptureErrors = Capture[Int]
    var first = CaptureErrors.borrow(prefix).mutable(state).take(String("!")).run(rmo)
    comptime assert type_of(first).E == Never
    assert_equal(first._ok().value, "prefix:old!")
    assert_equal(state, "old!")
    state = "old"
    assert_equal(CaptureErrors.borrow(prefix).take(String("!")).mutable(state).run(rom)._ok().value, "prefix:old!")
    assert_equal(state, "old!")
    state = "old"
    assert_equal(CaptureErrors.mutable(state).borrow(prefix).take(String("!")).run(mro)._ok().value, "prefix:old!")
    assert_equal(state, "old!")
    state = "old"
    assert_equal(CaptureErrors.mutable(state).take(String("!")).borrow(prefix).run(mor)._ok().value, "prefix:old!")
    assert_equal(state, "old!")
    state = "old"
    assert_equal(CaptureErrors.take(String("!")).borrow(prefix).mutable(state).run(orm)._ok().value, "prefix:old!")
    assert_equal(state, "old!")
    state = "old"
    assert_equal(CaptureErrors.take(String("!")).mutable(state).borrow(prefix).run(omr)._ok().value, "prefix:old!")
    assert_equal(state, "old!")
    assert_equal(prefix, "prefix:")


def read_registers(a: Int, b: Float64, c: Int) raises Int -> Int:
    raise a + Int(b) + c

def read_memory(a: String, b: List[Int], c: String) -> String:
    return a + String(b[0]) + c

def mutate_all(mut a: Int, mut b: String, mut c: List[Int]):
    a += 1
    b += "!"
    c.append(a)


def check_abi() raises:
    var a = 1
    var b = Float64(2)
    var c = 3
    var pointer: def(Int, Float64, Int) raises Int thin -> Int = read_registers
    assert_equal(Capture[Int]().borrow(a).borrow(b).borrow(c).run(pointer)._err().value, 6)
    assert_equal(Capture[Int]().borrow(a).borrow(b).borrow(c).run(read_registers)._err().value, 6)
    var prefix = String("[")
    var numbers: List[Int] = [7]
    var suffix = String("]")
    assert_equal(Capture().borrow(prefix).borrow(numbers).borrow(suffix).run(read_memory)._ok().value, "[7]")
    var mutated = Capture[Int]().mutable(a).mutable(prefix).mutable(numbers).run(mutate_all)
    comptime assert type_of(mutated).E == Never
    assert_equal(mutated.is_ok(), True)
    assert_equal(a, 2)
    assert_equal(prefix, "[!")
    assert_equal(numbers, [7, 2])
    var memory_pointer: def(String, mut String, var String) thin -> String = rmo
    assert_equal(Capture().borrow(prefix).mutable(suffix).take(String("!")).run(memory_pointer)._ok().value, "[!]!")


def check_captured() raises:
    var calls = 0
    def callback(prefix: String, mut state: Int, var message: String) raises Int {mut calls} -> String:
        calls += 1
        state += message.byte_length()
        if state > 5: raise state
        return prefix + message
    var prefix = String("value:")
    var state = 0
    comptime CaptureErrors = Capture[Int]
    assert_equal(CaptureErrors.borrow(prefix).mutable(state).take(String("abc")).run(callback)._ok().value, "value:abc")
    assert_equal(CaptureErrors.borrow(prefix).mutable(state).take(String("def")).run(callback)._err().value, 6)
    assert_equal(state, 6)
    assert_equal(calls, 2)


def main() raises:
    check_orders()
    check_abi()
    check_captured()
