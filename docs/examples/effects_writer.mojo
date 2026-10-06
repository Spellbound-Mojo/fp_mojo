"""Accumulate a pricing log with Writer, then inspect and format it."""
from fp.algebra import flat_map, StringMonoid
from fp.effects import Writer, writer, tell, listen, censor, run_writer
from std.testing import assert_equal


comptime PricingWriter = Writer[StringMonoid]


def add_fee(amount: Int) -> type_of(writer[PricingWriter, Int](Tuple(String(), 0))):
    return writer[PricingWriter, Int](Tuple(String("fee +2"), amount + 2))


def bracket(var log: String) -> String:
    return "[" + log + "]"


def main() raises:
    var notice = run_writer[PricingWriter](tell[PricingWriter]("ready"))
    assert_equal(notice[0], "ready")
    comptime assert type_of(notice[1]) == NoneType
    print("notice:", notice[0])

    var initial = writer[PricingWriter, Int](Tuple(String("start; "), 3))
    var charged = flat_map[PricingWriter](add_fee, initial^)
    var observed = listen[PricingWriter](charged^)
    var formatted = censor[PricingWriter](bracket, observed^)
    var output = run_writer[PricingWriter](formatted^)
    assert_equal(output[0], "[start; fee +2]")
    assert_equal(output[1][0], 5)
    assert_equal(output[1][1], "start; fee +2")
    print("value:", output[1][0])
    print("log:", output[0])
    print("log copied by listen:", output[1][1])
