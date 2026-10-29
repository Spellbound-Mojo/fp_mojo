"""State output selection moves owners and releases the unselected element once."""
from fp.effects import State, StateT, StateAction, Reader, inspect
from fp.functions import pipeline
from fp.algebra import ListFamily
from fp.callables import BorrowOnceCallable
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct OutputOwner(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct OutputFailure(Movable):
    var owner: OutputOwner


@fieldwise_init
struct ProjectOwner(BorrowOnceCallable):
    var owner: OutputOwner
    var calls: ArcPointer[Int]
    var fail: Bool
    comptime Payload = OutputOwner
    comptime Result = OutputOwner
    comptime Failure = OutputFailure
    def invoke_once(deinit self,ref state: Self.Payload) raises Self.Failure -> Self.Result:
        self.calls[] += 1
        if self.fail: raise OutputFailure(self.owner^)
        self.owner.value += state.value
        return self.owner^


@fieldwise_init
struct MultipleOutputs(StateAction):
    var drops: ArcPointer[Int]
    comptime Family = StateT[ListFamily,OutputOwner]
    comptime State = OutputOwner
    comptime Value = OutputOwner
    comptime Out = List[Tuple[OutputOwner,OutputOwner]]
    def run(deinit self,var state: Self.State) -> Self.Out:
        var values = List[Tuple[OutputOwner,OutputOwner]]()
        values.append((OutputOwner(7,self.drops),state^))
        values.append((OutputOwner(8,self.drops),OutputOwner(12,self.drops)))
        return values^


def main() raises:
    comptime assert not conforms_to(OutputOwner,Copyable)
    comptime S = State[OutputOwner]
    for state_only in range(2):
        for mode in range(3):
            var values = ArcPointer(0)
            var states = ArcPointer(0)
            var calls = ArcPointer(0)
            var recipe = pipeline(inspect[S](ProjectOwner(OutputOwner(7,values),calls,mode == 1)))
            var initial = OutputOwner(11,states)
            assert_equal(calls[],0)
            if mode == 2:
                _ = recipe^
                assert_equal(values[],1)
                assert_equal(states[],0)
                _ = initial^
            else:
                var result: Optional[OutputOwner] = None
                var failure: Optional[OutputFailure] = None
                try:
                    if state_only: result = Optional(recipe^.run_state(initial^))
                    else: result = Optional(recipe^.run_value(initial^))
                except error: failure = Optional(error^)
                assert_equal(calls[],1)
                assert_equal(Bool(failure),mode == 1)
                if mode == 0:
                    assert_equal(values[],Int(state_only))
                    assert_equal(states[],1 - state_only)
                    var selected = result.take()
                    assert_equal(selected.value,11 if state_only else 18)
                    _ = selected^
                else:
                    assert_equal(states[],1)
                    assert_equal(values[],0)
                    var raised = failure.take()
                    assert_equal(raised.owner.value,7)
                    _ = raised^
            assert_equal(values[],1)
            assert_equal(states[],1)

    comptime D = StateT[Reader[Int],OutputOwner]
    for state_only in range(2):
        for abandon in range(2):
            var drops = ArcPointer(0)
            var source = pipeline(D.pure(OutputOwner(7,drops)))
            var initial = OutputOwner(11,drops)
            if state_only:
                var pending = source^.run_state(initial^)
                assert_equal(drops[],0)
                if abandon: _ = pending^
                else:
                    var output = pipeline(pending^).run(0)
                    assert_equal(drops[],1)
                    assert_equal(output.value,11)
                    _ = output^
            else:
                var pending = source^.run_value(initial^)
                assert_equal(drops[],0)
                if abandon: _ = pending^
                else:
                    var output = pipeline(pending^).run(0)
                    assert_equal(drops[],1)
                    assert_equal(output.value,7)
                    _ = output^
            assert_equal(drops[],2)

    for state_only in range(2):
        var drops = ArcPointer(0)
        var source = pipeline(MultipleOutputs(drops))
        var initial = OutputOwner(11,drops)
        var outputs: List[OutputOwner]
        if state_only: outputs = source^.run_state(initial^)
        else: outputs = source^.run_value(initial^)
        assert_equal(len(outputs),2)
        assert_equal(outputs[0].value,11 if state_only else 7)
        assert_equal(outputs[1].value,12 if state_only else 8)
        assert_equal(drops[],2)
        _ = outputs^
        assert_equal(drops[],4)
