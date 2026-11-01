"""Accumulate a pricing log with Writer, then inspect and format it."""
from fp.algebra import StringMonoid
from fp.functions import pipeline
from fp.effects import Writer, writer, tell
from std.testing import assert_equal


comptime PricingWriter = Writer[StringMonoid]


def add_fee(amount: Int) -> Int:
    return amount + 2


def bracket(var log: String) -> String:
    return "[" + log + "]"


def main() raises:
    var notice = pipeline(tell[PricingWriter]("ready")).run_log()
    assert_equal(notice, "ready")
    print("notice:", notice)

    var initial = writer[PricingWriter, Int](Tuple(String("start; "), 3))
    var output = pipeline(initial^).map(add_fee).tell("fee +2").listen().censor(bracket).run()
    assert_equal(output[0], "[start; fee +2]")
    assert_equal(output[1][0], 5)
    assert_equal(output[1][1], "start; fee +2")
    print("value:", output[1][0])
    print("log:", output[0])
    print("log copied by listen:", output[1][1])
