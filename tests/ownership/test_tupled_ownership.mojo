"""Pair adaptation preserves payload moves, receiver captures and output origins."""
from fp.functions import tupled, partial
from fp.iteration import iterated
from test_binary_callback_views_ownership import KeepFirst, Prefix, selected
from test_native_binary_pointers_ownership import keep, fail
from test_ior_ownership import IOToken, IOCombine, IOFailCombine
from algebra_support.result_ownership import Token, trace
from std.memory import ArcPointer
from std.iter import next
from std.testing import assert_equal, assert_true

def shared() raises:
    var captures = trace()
    var payloads = trace()
    var callback = tupled(KeepFirst(Token(0, captures)))
    comptime assert not conforms_to(type_of(callback), Copyable)
    var source: List[Tuple[Token, Token]] = [
        (Token(1, payloads), Token(2, payloads)),
        (Token(3, payloads), Token(4, payloads)),
    ]
    var pending = iterated(source^).map(callback)
    assert_equal(captures[].calls, 0)
    var result = next(pending)
    assert_equal(result.id, 1)
    assert_equal(captures[].calls, 1)
    assert_equal(payloads[].drops[2], 1)
    _ = pending^
    assert_equal(payloads[].drops[3], 1)
    assert_equal(payloads[].drops[4], 1)
    assert_equal(captures[].drops[0], 0)
    var abandoned = iterated(List[Tuple[Token, Token]]()).map(callback^)
    _ = abandoned^
    assert_equal(captures[].calls, 1)
    assert_equal(captures[].drops[0], 1)
    _ = result^
    assert_equal(payloads[].drops[1], 1)

def consumed() raises:
    var drops = ArcPointer(List[Int]([0, 0, 0, 0]))
    var calls = ArcPointer(0)
    var callback = tupled(IOCombine(IOToken(3, drops), calls))
    var result = callback^.call_once((IOToken(1, drops), IOToken(2, drops)))
    assert_equal(calls[], 1)
    assert_equal(result.id, 1)
    assert_equal(drops[][1], 0)
    assert_equal(drops[][2], 1)
    assert_equal(drops[][3], 1)
    _ = result^
    assert_equal(drops[][1], 1)
    var errors = ArcPointer(List[Int]([0, 0, 0, 0]))
    var failure = tupled(IOFailCombine(IOToken(3, errors)))
    var observed = False
    try: _ = failure^.call_once((IOToken(1, errors), IOToken(2, errors)))
    except error:
        comptime assert type_of(error) == String
        observed = error == "binary failure"
    assert_true(observed)
    for id in range(1, 4): assert_equal(errors[][id], 1)

def native_errors() raises:
    var payloads = trace()
    var pointer: def(var Token, var Token) raises Token thin -> Token = fail[Token]
    var callback = tupled(pointer)
    var observed = 0
    try: _ = callback((Token(1, payloads), Token(2, payloads)))
    except error:
        comptime assert type_of(error) == Token
        observed = error.id
    assert_equal(observed, 1)
    assert_equal(payloads[].drops[1], 1)
    assert_equal(payloads[].drops[2], 1)

def prefix_copies() raises:
    var ledger = trace()
    var payloads = trace()
    var prefix = Prefix(ledger)
    var callback = tupled(partial(selected, prefix))
    assert_equal(ledger[].factories, 1)
    assert_equal(ledger[].calls, 0)
    assert_equal(callback((Token(1, payloads), Token(2, payloads))), 3)
    assert_equal(ledger[].factories, 2)
    assert_equal(ledger[].calls, 1)
    assert_equal(ledger[].restarts, 0)
    assert_equal(payloads[].drops[1], 1)
    assert_equal(payloads[].drops[2], 1)
    _ = callback^
    assert_equal(ledger[].drops[0], 2)
    _ = prefix^
    assert_equal(ledger[].drops[0], 3)

def external(owner: List[Int]) -> Span[Int, origin_of(owner)]:
    var view = Span(owner)
    comptime View = type_of(view)
    var pointer: def(var View, var View) thin -> View = keep[View]
    return tupled(pointer)((view, view))

def main() raises:
    shared()
    consumed()
    native_errors()
    prefix_copies()
    var owner: List[Int] = [7, 11]
    var result = external(owner)
    assert_true(Pointer(to=result[1]) == Pointer(to=owner[1]))
