from fp.data import Capture, Result
from std.testing import assert_equal

@fieldwise_init
struct Fault(Movable):
    var code: Int

def scalar(mut state: Int, var value: Int) -> Int:
    state += value
    return state

def different(mut state: Int, var value: Int) -> Int:
    state += 100 * value
    return state

def memory(mut state: Int, var value: String) -> String:
    state += value.byte_length()
    return value^

def register_memory(mut state: Int, var value: Int) raises Never -> String:
    state += value
    return String(state)

def memory_register(mut state: Int, var value: String) raises Fault -> Int:
    state += value.byte_length()
    if value.byte_length() == 0:
        raise Fault(state)
    return state

def no_value(mut state: Int, var value: Int) raises Never:
    state += value

def generic[S: Movable & Deinitable, A: Movable & Deinitable,
            R: Movable & Deinitable, E: Movable & Deinitable, //](
    function: def(mut S, var A) raises E thin -> R, var state: S, var value: A
) -> Result[R, E]:
    var owner = Capture[E]().stateful(function, state^)
    return owner.run(value^)

def main() raises:
    var pointer: def(mut Int, var Int) thin -> Int = scalar
    var first = Capture().stateful(pointer, 1)
    pointer = different
    assert_equal(first.run(2)._ok().value, 3)
    assert_equal(first.run(4)._ok().value, 7)
    assert_equal(first^.into_state(), 7)
    var replaced = Capture().stateful(pointer, 1)
    assert_equal(replaced.run(2)._ok().value, 201)

    var mm: def(mut Int, var String) thin -> String = memory
    var second = Capture().stateful(mm, 1)
    assert_equal(second.run("abc")._ok().value, "abc")
    assert_equal(second.state(), 4)

    var rm: def(mut Int, var Int) raises Never thin -> String = register_memory
    var third = Capture().stateful(rm, 1)
    var success = third.run(3)
    comptime assert type_of(success) == Result[String, Never]
    assert_equal(success._ok().value, "4")

    var mr: def(mut Int, var String) raises Fault thin -> Int = memory_register
    var fourth = Capture[Fault]().stateful(mr, 1)
    assert_equal(fourth.run("abc")._ok().value, 4)
    assert_equal(fourth.run("")._err().value.code, 4)
    assert_equal(fourth.run("ab")._ok().value, 6)
    assert_equal(fourth^.into_state(), 6)

    var empty: def(mut Int, var Int) raises Never thin = no_value
    var fifth = Capture().stateful(empty, 1)
    var void = fifth.run(3)
    comptime assert type_of(void) == Result[type_of(None), Never]
    assert_equal(void.is_ok(), True)
    assert_equal(fifth.state(), 4)
    assert_equal(generic(memory_register, 1, String("ab"))._ok().value, 3)
    assert_equal(generic(register_memory, 1, 2)._ok().value, "3")
