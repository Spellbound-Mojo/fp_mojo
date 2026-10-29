from fp.algebra import ErrorRecovery, AttemptContract, ResultFamily
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct Owned[o: ImmOrigin](Movable):
    var span: Span[Int, Self.o]
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1


def forwarded[I: ErrorRecovery, V: Movable & Deinitable](var source: V) raises AttemptContract[I, V].Error -> AttemptContract[I, V].Out where AttemptContract[I, V].Compatible:
    return pipeline[I](source^).attempt().get()


def exercise[o: ImmOrigin](ref[o] values: List[Int]) raises:
    comptime I = ResultFamily[Owned[o]]
    var success_drops = ArcPointer(0)
    var error_drops = ArcPointer(0)
    var success = forwarded[I](Result[Owned[o], Owned[o]](Ok(Owned(Span(values), success_drops.copy()))))
    var value = success^._take_ok()._take_ok()
    assert_equal(value.span[0], 41)
    assert_equal(success_drops[], 0)
    _ = value^
    assert_equal(success_drops[], 1)
    var failed = forwarded[I](Result[Owned[o], Owned[o]](Err(Owned(Span(values), error_drops.copy()))))
    var error = failed^._take_ok()._take_err()
    assert_equal(error.span[0], 41)
    assert_equal(error_drops[], 0)
    _ = error^
    assert_equal(error_drops[], 1)


def main() raises:
    var values: List[Int] = [41]
    exercise(values)
    print("Pipeline attempt: move-only successes and failures, exact external origins, one destruction")
