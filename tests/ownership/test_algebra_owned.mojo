"""Move-only algebra payloads and consuming callbacks use native cleanup."""
from fp.algebra import map, IdentityFamily, OptionalFamily
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true
from test_attempt_once import Trace, Token
from test_result_once import Transform


def main() raises:
    for active in [False,True]:
        for fail in [False,True]:
            var trace=ArcPointer(Trace(0,SIMD[DType.int64,4](0)))
            var source=Optional[Token[2]]()
            if active:
                source=Optional(Token[2](3,trace))
            var caught=False
            var present=False
            var payload=0
            try:
                var output=map[OptionalFamily](Transform(Token[1](10,trace),fail),source^)
                present=Bool(output)
                if active:
                    payload=output.value().value
                _=output^
            except error:
                comptime assert type_of(error)==Token[2]
                caught=True
                payload=error.value
            assert_equal(caught,active and fail)
            assert_equal(present,active and not fail)
            assert_equal(payload,13 if active else 0)
            assert_equal(trace[].calls,Int(active))
            assert_equal(trace[].drops[1],1)
            assert_equal(Int(trace[].drops[2]),Int(active))
    var trace=ArcPointer(Trace(0,SIMD[DType.int64,4](0)))
    var identity_value=0
    var identity_caught=False
    try:
        var output=map[IdentityFamily](Transform(Token[1](10,trace),False),Token[2](3,trace))
        identity_value=output.value
        _=output^
    except error:
        comptime assert type_of(error)==Token[2]
        identity_caught=True
    assert_equal(identity_value,13)
    assert_true(not identity_caught)
    assert_equal(trace[].calls,1)
    assert_equal(trace[].drops[1],1)
    assert_equal(trace[].drops[2],1)
    print("algebra ownership: selected/absent/raising cleanup")
