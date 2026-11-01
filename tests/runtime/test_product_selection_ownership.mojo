"""Selection moves payloads, destroys discarded owners and retains origins."""
from fp.functions import pipeline
from fp.algebra import product_l, product_r, OptionalFamily, pure
from fp.effects import Reader
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal
from test_context_failure_forwarding_ownership import Owner


def origins[a: ImmOrigin,b: ImmOrigin](ref[a] first: Int,ref[b] second: Int) raises:
    var left = product_l[OptionalFamily](Optional(Pointer(to=first)),Optional(Pointer(to=second)))
    var right = pipeline(Optional(Pointer(to=first))).product_r(Optional(Pointer(to=second))).get()
    comptime assert type_of(left) == Optional[Pointer[Int,a]]
    comptime assert type_of(right) == Optional[Pointer[Int,b]]
    assert_equal(left.value()[],first)
    assert_equal(right.value()[],second)


def discarded_origin() -> Optional[Int]:
    var local = 7
    return pipeline(Optional(Pointer(to=local))).product_r(Optional(11)).get()


def main() raises:
    assert_equal(discarded_origin().value(),11)
    comptime for keep_left in range(2):
        var trace = ArcPointer(String())
        comptime if keep_left:
            var result = pipeline(Optional(Owner(1,trace))).product_l(Optional(Owner(2,trace))).get()
            assert_equal(trace[],"2")
            var kept = result.take()
            assert_equal(kept.id,1)
            _ = kept^
            assert_equal(trace[],"21")
        else:
            var result = product_r[OptionalFamily](Optional(Owner(1,trace)),Optional(Owner(2,trace)))
            assert_equal(trace[],"1")
            var kept = result.take()
            assert_equal(kept.id,2)
            _ = kept^
            assert_equal(trace[],"12")
    var skipped = ArcPointer(String())
    _ = pipeline(Optional[Owner]()).product_r(Optional(Owner(2,skipped))).get()
    assert_equal(skipped[],"2")
    _ = pipeline(Optional(Owner(1,skipped))).product_l(Optional[Owner]()).get()
    assert_equal(skipped[],"21")
    var failed = ArcPointer(String())
    var source: Result[Owner,Owner] = Err(Owner(3,failed))
    var other: Result[Owner,Owner] = Ok(Owner(2,failed))
    var result = pipeline(source^).product_r(other^).get()
    assert_equal(result.is_err(),True)
    assert_equal(failed[],"2")
    _ = result^
    assert_equal(failed[],"23")
    comptime for execute in range(2):
        var deferred = ArcPointer(String())
        comptime R = Reader[Int]
        var pending = pipeline(pure[R](Owner(1,deferred))).product_r(pure[R](Owner(2,deferred)))
        assert_equal(deferred[],"")
        comptime if execute:
            var selected = pending^.run(0)
            assert_equal(deferred[],"1")
            assert_equal(selected.id,2)
            _ = selected^
        else:
            _ = pending^
        assert_equal(deferred[].count("1"),1)
        assert_equal(deferred[].count("2"),1)
    var first = 7
    var second = 11
    origins(first,second)
