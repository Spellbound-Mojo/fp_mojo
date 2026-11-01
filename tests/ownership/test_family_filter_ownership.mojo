"""Filtering borrows move-only payloads and retains caller-owned mutable callbacks."""
from fp.callables import BorrowMutableCallable, mut_ref
from fp.functions import pipeline
# ContainerDeferredFamily is Filterable but not a Functor, so it uses the family-selected free functions.
from fp.algebra import filter, filter_not
from algebra_support.filtering import ContainerDeferredFamily
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal


@fieldwise_init
struct Predicate(BorrowMutableCallable):
    comptime Payload = Token
    comptime Result = Bool
    comptime Failure = Token
    var capture: Token
    var fail: Bool
    def invoke_mut(mut self, ref value: Token) raises Token -> Bool:
        self.capture.trace[].calls += 1
        if self.fail and value.id == 2:
            raise Token(7, self.capture.trace)
        return value.id % 2 == 1


def execute[deferred: Bool, inverted: Bool](fail: Bool) raises:
    var state = trace()
    var predicate = Predicate(Token(6, state), fail)
    var input: List[Token] = [Token(1, state), Token(2, state), Token(3, state)]
    var output = List[Token]()
    var raised = False
    try:
        comptime if deferred:
            comptime if inverted:
                var pending = filter_not[ContainerDeferredFamily](input^, mut_ref(predicate))
                output = pending^.run()
            else:
                var pending = filter[ContainerDeferredFamily](input^, mut_ref(predicate))
                output = pending^.run()
        elif inverted:
            output = pipeline(input^).filter_not(mut_ref(predicate)).get()
        else:
            output = pipeline(input^).filter(mut_ref(predicate)).get()
    except error:
        comptime assert type_of(error) == Token
        raised = True
    assert_equal(raised, fail)
    assert_equal(state[].calls, 2 if fail else 3)
    assert_equal(state[].drops[6], 0)
    assert_equal(state[].drops[7], Int(fail))
    if not fail:
        assert_equal(len(output), 1 if inverted else 2)
        assert_equal(output[0].id, 2 if inverted else 1)
    _ = output^
    for id in range(1, 4): assert_equal(state[].drops[id], 1)
    assert_equal(predicate.fail, fail)
    _ = predicate^
    assert_equal(state[].drops[6], 1)


def abandoned() raises:
    var state = trace()
    var predicate = Predicate(Token(6, state), False)
    var input: List[Token] = [Token(1, state)]
    var pending = filter[ContainerDeferredFamily](input^, mut_ref(predicate))
    _ = pending^
    assert_equal(state[].calls, 0)
    assert_equal(state[].drops[1], 1)
    assert_equal(state[].drops[6], 0)
    assert_equal(predicate.fail, False)
    _ = predicate^
    assert_equal(state[].drops[6], 1)


@fieldwise_init
struct NonEmpty[o: ImmOrigin](BorrowMutableCallable):
    comptime Payload = Span[Int, Self.o]
    comptime Result = Bool
    var calls: Int
    def invoke_mut(mut self, ref value: Self.Payload) -> Bool:
        self.calls += 1
        return len(value) > 0


def external(owner: List[Int]) -> List[Span[Int, origin_of(owner)]]:
    comptime View = Span[Int, origin_of(owner)]
    var predicate = NonEmpty[origin_of(owner)](0)
    var values: List[View] = [Span(owner), Span(owner)[1:]]
    return pipeline(values^).filter(mut_ref(predicate)).get()


def main() raises:
    comptime for deferred in range(2):
        comptime for inverted in range(2):
            execute[Bool(deferred), Bool(inverted)](False)
            execute[Bool(deferred), Bool(inverted)](True)
    abandoned()
    var owner: List[Int] = [7, 11]
    var output = external(owner)
    assert_equal(Pointer(to=output[1][0]) == Pointer(to=owner[1]), True)
