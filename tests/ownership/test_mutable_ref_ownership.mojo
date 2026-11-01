"""Borrowed callback state outlives execution, failure and deferred abandonment."""
from fp.callables import MutableUnary, BorrowMutableCallable, mut_ref
from fp.functions import pipeline
from fp.iteration import iterated
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal


@fieldwise_init
struct Transform(MutableUnary):
    comptime Arg = Token
    comptime Out = Token
    comptime Error = Token
    var capture: Token
    var fail: Bool
    def call_mut(mut self, var value: Token) raises Token -> Token:
        self.capture.trace[].calls += 1
        if self.fail and value.id == 2:
            raise Token(7, self.capture.trace)
        return value^


def execution(fail: Bool) raises:
    var state = trace()
    var callback = Transform(Token(6, state), fail)
    var input: List[Token] = [Token(1, state), Token(2, state), Token(3, state)]
    var output = List[Token]()
    var raised = False
    try:
        output = pipeline(input^).map(mut_ref(callback)).get()
    except error:
        comptime assert type_of(error) == Token
        raised = True
    assert_equal(raised, fail)
    assert_equal(state[].calls, 2 if fail else 3)
    assert_equal(state[].drops[6], 0)
    assert_equal(state[].drops[7], Int(fail))
    assert_equal(callback.fail, fail)
    _ = callback^
    assert_equal(state[].drops[6], 1)
    _ = output^
    for id in range(1, 4):
        assert_equal(state[].drops[id], 1)


@fieldwise_init
struct Observer(BorrowMutableCallable):
    comptime Payload = Token
    comptime Result = Int
    var capture: Token
    var calls: Int
    def invoke_mut(mut self, ref value: Token) -> Int:
        self.calls += 1
        return value.id


def deferred() raises:
    var state = trace()
    var callback = Observer(Token(6, state), 0)
    var abandoned_input: List[Token] = [Token(1, state)]
    var abandoned = iterated(abandoned_input^).pair_with(mut_ref(callback))
    _ = abandoned^
    assert_equal(callback.calls, 0)
    assert_equal(state[].drops[1], 1)
    var input: List[Token] = [Token(2, state), Token(3, state)]
    var pending = iterated(input^).pair_with(mut_ref(callback))
    var output = pending^.to_list()
    assert_equal(callback.calls, 2)
    assert_equal(state[].drops[6], 0)
    assert_equal(output[1][0].id, 3)
    assert_equal(output[1][1], 3)
    _ = output^
    assert_equal(state[].drops[2], 1)
    assert_equal(state[].drops[3], 1)
    assert_equal(callback.calls, 2)
    _ = callback^
    assert_equal(state[].drops[6], 1)


@fieldwise_init
struct Project[o: ImmOrigin](MutableUnary):
    comptime Arg = Int
    comptime Out = Span[Int, Self.o]
    var values: Self.Out
    var calls: Int
    def call_mut(mut self, var offset: Int) -> Self.Out:
        self.calls += 1
        return self.values[offset:]


def external(owner: List[Int]) -> List[Span[Int, origin_of(owner)]]:
    var callback = Project(Span(owner), 0)
    return pipeline[List[Int]]([0, 1]).map(mut_ref(callback)).get()


def main() raises:
    execution(False)
    execution(True)
    deferred()
    var owner: List[Int] = [7, 11]
    var output = external(owner)
    assert_equal(Pointer(to=output[1][0]) == Pointer(to=owner[1]), True)
