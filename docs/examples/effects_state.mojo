"""Read, update and reset a counter through State computations."""
from fp.functions import pipeline
from fp.effects import State, get, modify, put
from std.testing import assert_equal


comptime CounterState = State[Int]


def ticket(counter: Int) -> String:
    return "ticket " + String(counter)


def increment(counter: Int) -> Int:
    return counter + 1


def main() raises:
    var described = pipeline(get[CounterState]()).map(ticket).run(10)
    assert_equal(described[0], "ticket 10")
    assert_equal(described[1], 10)
    print("read:", described[0], "; state =", described[1])

    var advance = modify[CounterState](increment)
    var advanced = pipeline(advance^).followed_by(get[CounterState]).run(10)
    assert_equal(advanced[0], 11)
    assert_equal(advanced[1], 11)
    print("update: value =", advanced[0], "; state =", advanced[1])

    var cleared = pipeline(put[CounterState](0)).followed_by(get[CounterState]).run(10)
    assert_equal(cleared[0], 0)
    assert_equal(cleared[1], 0)
    print("reset: value =", cleared[0], "; state =", cleared[1])
