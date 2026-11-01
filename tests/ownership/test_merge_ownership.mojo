"""Merging copies only the input and preserves branch order and all owner cleanup."""
from fp.functions import merge
from fp.callables import OnceUnary, Unary
from fp.iteration import iterated
from algebra_support.result_ownership import Token, Trace, trace
from std.memory import ArcPointer
from std.iter import next
from std.testing import assert_equal, assert_true

@fieldwise_init
struct Item(Copyable):
    var id: Int
    var ledger: ArcPointer[Trace]
    var copied: Bool
    def __init__(out self, *, copy: Self):
        self.id = copy.id
        self.ledger = copy.ledger
        self.copied = True
        self.ledger[].factories += 1
    def __deinit__(deinit self): self.ledger[].drops[self.id] += 1

@fieldwise_init
struct Observe(OnceUnary):
    comptime Arg = Item
    comptime Out = Token
    comptime Error = Token
    var capture: Token
    var expects_copy: Bool
    var fails: Bool
    def call_once(deinit self, var item: Item) raises Token -> Token:
        assert item.copied == self.expects_copy
        self.capture.trace[].calls = self.capture.trace[].calls * 10 + self.capture.id
        var value = Token(self.capture.id, self.capture.trace)
        if self.fails: raise value^
        return value^

@fieldwise_init
struct Keep(Unary):
    comptime Arg = Item
    comptime Out = Item
    var capture: Token
    def call(self, var item: Item) -> Item:
        self.capture.trace[].calls += 1
        return item^

def identity[T: Movable & Deinitable](var value: T) -> T: return value^
def external(owner: List[Int]) -> Tuple[Span[Int, origin_of(owner)], Span[Int, origin_of(owner)]]:
    var view = Span(owner)
    comptime View = type_of(view)
    var pointer: def(var View) thin -> View = identity[View]
    return merge(pointer, pointer)(view)

def main() raises:
    for fail in range(3):
        var inputs = trace()
        var callbacks = trace()
        var f = merge(Observe(Token(5, callbacks), True, fail == 1),
                      Observe(Token(6, callbacks), False, fail == 2))
        assert_equal(inputs[].factories, 0)
        assert_equal(callbacks[].calls, 0)
        var observed = 0
        try:
            var pair = f^.call_once(Item(1, inputs, False))
            assert pair[0].id == 5 and pair[1].id == 6
        except error:
            observed = error.id
        assert_equal(observed, 0 if fail == 0 else fail + 4)
        assert_equal(callbacks[].calls, 5 if fail == 1 else 56)
        assert_equal(inputs[].factories, 1)
        assert_equal(inputs[].drops[1], 2)
        assert_equal(callbacks[].drops[5], 2)
        assert_equal(callbacks[].drops[6], 1 if fail == 1 else 2)
    var inputs = trace()
    var callbacks = trace()
    var f = merge(Keep(Token(5, callbacks)), Keep(Token(6, callbacks)))
    var values: List[Item] = [Item(1, inputs, False), Item(2, inputs, False)]
    var pending = iterated(values^).map(f)
    assert_equal(inputs[].factories, 0)
    var pair = next(pending)
    assert_equal(inputs[].factories, 1)
    assert_true(pair[0].copied)
    assert_true(not pair[1].copied)
    _ = pending^
    assert_equal(inputs[].drops[2], 1)
    assert_equal(inputs[].drops[1], 0)
    assert_equal(callbacks[].calls, 2)
    _ = f^
    assert_equal(callbacks[].drops[5], 1)
    assert_equal(callbacks[].drops[6], 1)
    _ = pair^
    assert_equal(inputs[].drops[1], 2)
    var owner: List[Int] = [7, 11]
    var result = external(owner)
    assert_true(Pointer(to=result[0][1]) == Pointer(to=owner[1]))
    assert_true(Pointer(to=result[1][1]) == Pointer(to=owner[1]))
