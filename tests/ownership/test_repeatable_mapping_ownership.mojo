"""Stateful lazy callbacks retain noncopyable owners and preserve native origins."""
from fp.callables import MutableUnary
from fp.iteration import iterated
from algebra_support.result_ownership import Token, Trace, trace
from std.iter import next, Iterator
from std.memory import ArcPointer
from std.builtin.rebind import rebind_var
from std.testing import assert_equal, assert_true

@fieldwise_init
struct Keep(MutableUnary):
    comptime Arg = Token
    comptime Out = Token
    var owner: Token
    def call_mut(mut self, var value: Token) -> Token:
        self.owner.trace[].calls += 1
        return value^

@fieldwise_init
struct Choose(MutableUnary):
    comptime Arg = Token
    comptime Out = Optional[Token]
    var owner: Token
    def call_mut(mut self, var value: Token) -> Optional[Token]:
        self.owner.trace[].calls += 1
        if value.id % 2 == 0: return Optional(value^)
        return None

@fieldwise_init
struct Expand(MutableUnary):
    comptime Arg = Token
    comptime Out = List[Token]
    var owner: Token
    def call_mut(mut self, var value: Token) -> List[Token]:
        self.owner.trace[].calls += 1
        var values = List[Token]()
        values.append(value^)
        return values^

def check[I: Iterator](var pending: I, captures: ArcPointer[Trace], payloads: ArcPointer[Trace], expected: Int) raises where I.Element == Token:
    assert_equal(captures[].calls, 0)
    assert_equal(captures[].drops[0], 0)
    comptime assert I.Element == Token
    var result = rebind_var[Token](next(pending))
    assert_equal(result.id, expected)
    assert_equal(captures[].calls, expected)
    _ = pending^
    assert_equal(captures[].drops[0], 1)
    assert_equal(payloads[].drops[result.id], 0)
    _ = result^
    for id in range(1, 4): assert_equal(payloads[].drops[id], 1)

def abandon[mode: Int]() raises:
    var captures = trace()
    var payloads = trace()
    var values: List[Token] = [Token(1, payloads), Token(2, payloads), Token(3, payloads)]
    comptime if mode == 0:
        check(iterated(values^).map(Keep(Token(0, captures))), captures, payloads, 1)
    elif mode == 1:
        check(iterated(values^).filter_map(Choose(Token(0, captures))), captures, payloads, 2)
    else:
        check(iterated(values^).flat_map(Expand(Token(0, captures))), captures, payloads, 1)

@fieldwise_init
struct KeepSpan[o: ImmOrigin](MutableUnary):
    comptime Arg = Span[Int, Self.o]
    comptime Out = Span[Int, Self.o]
    var calls: Int
    def call_mut(mut self, var value: Self.Arg) -> Self.Out:
        self.calls += 1
        return value

def external(owner: List[Int]) raises -> Span[Int, origin_of(owner)]:
    var view = Span(owner)
    var values: List[type_of(view)] = [view]
    var output = iterated(values^).map(KeepSpan[origin_of(owner)](0))
    return next(output)

def main() raises:
    abandon[0]()
    abandon[1]()
    abandon[2]()
    var owner: List[Int] = [7, 11]
    var result = external(owner)
    assert_true(Pointer(to=result[1]) == Pointer(to=owner[1]))
