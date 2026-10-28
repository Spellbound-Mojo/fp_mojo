"""Owned counted-loop bodies release captures and preserve exact carry/error ownership."""
from fp.control import fori_loop
from fp.callables import MutableBinary
from test_fori_loop_mut_ownership import Carry, Step, Keep
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal

@fieldwise_init
struct Recorded(MutableBinary):
    comptime First = Int
    comptime Second = Carry
    comptime Out = Carry
    comptime Error = Token
    var inner: Step
    def call_mut(mut self, var index: Int, var carry: Carry) raises Token -> Carry:
        return self.inner.call_mut(index,carry^)
    def __deinit__(deinit self):
        self.inner.capture.trace[].calls = self.inner.calls

def exercise[route: Int](fail: Bool) raises:
    var captures = trace()
    var payloads = trace()
    var saved = Optional[Carry]()
    var observed = 0
    var body = Recorded(Step(Token(5,captures),0,2 if fail else -1))
    try:
        comptime if route == 0:
            saved = Optional(fori_loop[unroll=2](0,5,body^,Carry(0,Token(1,payloads))))
        elif route == 1:
            saved = Optional(fori_loop[0,5,unroll=0](body^,Carry(0,Token(1,payloads))))
        elif route == 2:
            saved = Optional(fori_loop[0,5,unroll=3](body^,Carry(0,Token(1,payloads))))
        elif route == 3:
            saved = Optional(fori_loop(5,2,body^,Carry(7,Token(1,payloads))))
        else:
            saved = Optional(fori_loop[5,2,unroll=0](body^,Carry(7,Token(1,payloads))))
    except error:
        comptime assert type_of(error) == Token
        observed = error.id
    var failed = fail and route < 3
    assert_equal(observed,2 if failed else 0)
    assert_equal(captures[].calls,0 if route >= 3 else 3 if failed else 5)
    assert_equal(captures[].drops[5],1)
    assert_equal(payloads[].drops[1],Int(failed))
    assert_equal(payloads[].drops[2],Int(failed))
    if saved:
        var carry = saved.take()
        assert_equal(carry.value,7 if route >= 3 else 10)
    assert_equal(payloads[].drops[1],1)

def external(owner: List[Int]) -> Span[Int,origin_of(owner)]:
    return fori_loop(0,3,Keep[origin_of(owner)](0),Span(owner))

def main() raises:
    for fail in [False,True]:
        comptime for route in range(5): exercise[route](fail)
    var owner: List[Int] = [7,11]
    var view = external(owner)
    assert_equal(Pointer(to=view[1]) == Pointer(to=owner[1]),True)
