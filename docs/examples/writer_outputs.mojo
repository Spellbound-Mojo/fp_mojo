"""Run Writer for both outputs, or select its payload or log."""
from fp.effects import Writer, WriterT, writer, tell, run
from fp.algebra import StringMonoid, OptionalFamily
from fp.functions import pipeline
from std.testing import assert_equal


def add_fee(amount: Int) -> Int: return amount + 2


def main() raises:
    comptime W = Writer[StringMonoid]
    var both = run[W](writer[W,Int]((String("quoted"),3)))
    assert_equal(both,(String("quoted"),3))
    print("both:",both[0],both[1])

    var price = pipeline(writer[W,Int]((String("quoted; "),3))).map(add_fee).run_value()
    assert_equal(price,5)
    print("price:",price)

    var notice = pipeline(tell[W](String("ready"))).run_log()
    assert_equal(notice,"ready")
    print("log:",notice)

    comptime MaybeWriter = WriterT[OptionalFamily,StringMonoid]
    var maybe_price = pipeline(MaybeWriter.pure(7)).run_value()
    assert_equal(maybe_price.value(),7)
    print("optional price:",maybe_price.value())

    var absent = pipeline(writer[MaybeWriter,Int](Optional[Tuple[String,Int]]())).run_log()
    assert_equal(Bool(absent),False)
    print("log present:",Bool(absent))
