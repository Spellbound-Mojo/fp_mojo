"""Fluent folds retain the canonical terminal's moves, pulls, breaks and errors."""
from fp.callables import mut_ref
from fp.functions import pipeline
from fp.data import ControlFlow, Break, Continue
from algebra_support.result_ownership import Token, trace
from test_repeatable_folds_ownership import Source, Step, Until, Tail
from std.testing import assert_equal


def exercise[mode: Int](length: Int, fail: Bool) raises:
    var state = trace()
    var remaining = List[Token]()
    for i in range(length): remaining.append(Token(length-i,state))
    var source = Source(remaining^,Token(5,state))
    var step = Step(Token(6,state),fail)
    var result = Optional[Token]()
    var observed = 0
    try:
        comptime if mode == 0:
            result = Optional(pipeline(source^).fold_left(step^,Token(0,state)).get())
        elif mode == 1:
            result = Optional(pipeline(source^).fold_left(step^,Token(0,state)).get())
        elif mode == 2:
            result = pipeline(source^).reduce_optional(step^).get()
        else:
            var stopped = pipeline(source^).fold_until(Until(step^),Token(0,state)).get()
            if stopped.isa[Break[Token]]():
                result = Optional(stopped^.unwrap[Break[Token]]().into_payload())
            else:
                result = Optional(stopped^.unwrap[Continue[Token]]().into_payload())
    except error:
        comptime assert type_of(error) == Token
        observed = error.id
    var failed = fail and length >= 2
    var visited = 2 if length >= 2 and (failed or mode == 3) else length
    assert_equal(observed,7 if failed else 0)
    assert_equal(state[].calls,max(0,visited-1) if mode == 2 else visited)
    assert_equal(state[].pulls,visited if length >= 2 and (failed or mode == 3) else length+1)
    assert_equal(state[].drops[5],1)
    assert_equal(state[].drops[6],1)
    assert_equal(state[].drops[7],Int(failed))
    var carry_id = 1 if mode == 2 else 0
    if result:
        var value = result.take()
        for i in range(1,length+1): assert_equal(state[].drops[i],Int(i != carry_id))
        assert_equal(state[].drops[carry_id],0)
        assert_equal(value.id,carry_id)
    for i in range(1,length+1): assert_equal(state[].drops[i],1)
    assert_equal(state[].drops[0],0 if mode == 2 else 1)


def retained() raises:
    var state = trace()
    var values = List[Token]()
    values.append(Token(3,state))
    values.append(Token(2,state))
    values.append(Token(1,state))
    var step = Step(Token(6,state),True)
    var observed = 0
    try:
        _ = pipeline(Source(values^,Token(5,state))).fold_left(mut_ref(step),Token(0,state)).get()
    except error:
        observed = error.id
    assert_equal(observed,7)
    assert_equal(state[].calls,2)
    assert_equal(state[].pulls,2)
    assert_equal(state[].drops[6],0)
    _ = step^
    assert_equal(state[].drops[6],1)
    for i in range(4): assert_equal(state[].drops[i],1)
    assert_equal(state[].drops[5],1)
    assert_equal(state[].drops[7],1)


def external(owner: List[Int]) -> Span[Int,origin_of(owner)]:
    return pipeline[Int]([1]).fold_left(Tail[origin_of(owner)](),Span(owner)).get()


def main() raises:
    for length in range(4):
        for fail in [False,True]:
            comptime for mode in range(4): exercise[mode](length,fail)
    retained()
    var owner: List[Int] = [7,11]
    var view = external(owner)
    assert_equal(len(view),1)
    assert_equal(Pointer(to=view[0]) == Pointer(to=owner[1]),True)
