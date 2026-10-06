"""Read, update and reset a counter through State computations."""
from fp.algebra import map, flat_map
from fp.effects import State, get, modify, put, run
from std.testing import assert_equal


comptime CounterState = State[Int]


def ticket(counter: Int) -> String:
    return "ticket " + String(counter)


def increment(counter: Int) -> Int:
    return counter + 1


def read_counter(var unused: NoneType) -> type_of(get[CounterState]()):
    return get[CounterState]()


def main() raises:
    var label = map[CounterState](ticket, get[CounterState]())
    var described = run[CounterState](label^, 10)
    assert_equal(described[0], "ticket 10")
    assert_equal(described[1], 10)
    print("read:", described[0], "; state =", described[1])

    var advance = modify[CounterState](increment)
    var next_ticket = flat_map[CounterState](read_counter, advance^)
    var advanced = run[CounterState](next_ticket^, 10)
    assert_equal(advanced[0], 11)
    assert_equal(advanced[1], 11)
    print("update: value =", advanced[0], "; state =", advanced[1])

    var reset = flat_map[CounterState](read_counter, put[CounterState](0))
    var cleared = run[CounterState](reset^, 10)
    assert_equal(cleared[0], 0)
    assert_equal(cleared[1], 0)
    print("reset: value =", cleared[0], "; state =", cleared[1])
