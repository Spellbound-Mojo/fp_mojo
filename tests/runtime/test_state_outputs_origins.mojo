"""Selecting a State output retains independent value, state and error origins."""
from fp.effects import State, StateT, Reader, run_value, run_state, inspect
from fp.functions import pipeline
from std.testing import assert_equal


def check(values: List[Int],states: List[Int],errors: List[Int]) raises:
    comptime V = Span[Int,origin_of(values)]
    comptime S = Span[Int,origin_of(states)]
    comptime E = Span[Int,origin_of(errors)]
    comptime I = State[S]
    var selected = run_value[I](I.pure(Span(values)),Span(states))
    comptime assert type_of(selected) == V
    assert_equal(selected[0],11)
    var final_state = pipeline(I.pure(Span(values))).run_state(Span(states))
    comptime assert type_of(final_state) == S
    assert_equal(final_state[0],23)

    comptime D = StateT[Reader[Int],S]
    var deferred = pipeline(D.pure(Span(values))).run_value(Span(states))
    comptime assert type_of(deferred).Value == V
    var result = pipeline(deferred^).run(0)
    assert_equal(result[0],11)
    var deferred_state = run_state[D](D.pure(Span(values)),Span(states))
    comptime assert type_of(deferred_state).Value == S
    assert_equal(pipeline(deferred_state^).run(0)[0],23)

    var error_view = Span(errors)
    def fail(state: S) raises E {error_view} -> Int: raise error_view
    for state_only in range(2):
        var observed: Optional[E] = None
        try:
            if state_only: _ = pipeline(inspect[I](fail)).raising[String]().run_state(Span(states))
            else: _ = pipeline(inspect[I](fail)).raising[String]().run_value(Span(states))
        except error:
            comptime assert type_of(error) == E
            observed = Optional(error)
        assert_equal(observed.take()[0],71)


def main() raises:
    check([11],[23],[71])
