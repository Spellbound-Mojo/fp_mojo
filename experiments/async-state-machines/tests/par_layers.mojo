"""Parallel through OptionalT and ResultT over Async: Cats' nested semantics.

Every element runs to completion; the result is absent when any element is
absent, or holds the first stored error in element order. A base failure or
cancellation still stops and drains the rest, as AsyncPar does. Timing is
forced on TestControl's virtual clock: an absent or failing element settles at
once while the others sleep 50 ms.
"""
from std.os import abort
from fp.callables import Unary
from fp.data import Result, Ok, Err
from fp.effects import Outcome, OptionalT, ResultT
from fp.algebra import par_traverse, par_sequence, par_traverse_n, par_traverse_void_n
from fp.iteration import par_traverse_void, par_traverse as iter_par_traverse, par_sequence as iter_par_sequence
from fp.functions import pipeline
from fp.effects.async_runtime import IO, Async, Ref, Duration, Instant, TestControl, run

comptime A = Async[Int]
comptime OP = OptionalT[A]
comptime RP = ResultT[A, String]


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def ms(value: Int) -> Duration:
    try:
        return Duration.milliseconds(value)
    except:
        abort("a valid duration")


def inc(var count: Int) -> Int:
    return count + 1


def count_of(cell: Ref[Int]) -> Int:
    var outcome = run(cell.get[Int]())
    return outcome.take()._take_ok()


def since_zero(now: Instant) -> Int:
    return now.since(Instant()).to_nanoseconds()


def indices(n: Int) -> List[Int]:
    var values = List[Int]()
    for index in range(n):
        values.append(index)
    return values^


def success[T: Movable & Deinitable](var outcome: Outcome[T, Int]) -> T:
    if not outcome or not outcome.value().is_ok():
        abort("expected a successful IO")
    return outcome.take()._take_ok()


@fieldwise_init
struct Present(Unary, Copyable):
    var value: Int
    comptime Arg = NoneType
    comptime Out = Optional[Int]
    comptime Error = Never

    def call(self, var unit: NoneType) -> Optional[Int]:
        return Optional(self.value)


@fieldwise_init
struct Stored(Unary, Copyable):
    """A ResultT payload: Ok(value), or the stored error `e<index>` when `error` is set."""
    var value: Int
    var error: Bool
    comptime Arg = NoneType
    comptime Out = Result[Int, String]
    comptime Error = Never

    def call(self, var unit: NoneType) -> Result[Int, String]:
        if self.error:
            return Result[Int, String](Err(String("e", self.value)))
        return Result[Int, String](Ok(self.value * 3))


@fieldwise_init
struct FinishPresent(Unary, Copyable):
    """After the sleep: count the completion, then produce the OptionalT payload."""
    var done: Ref[Int]
    var payload: Present
    comptime Arg = NoneType
    comptime Out = IO[Optional[Int], Int]
    comptime Error = Never

    def call(self, var unit: NoneType) -> IO[Optional[Int], Int]:
        return self.done.update[Int](inc).map(self.payload.copy())


@fieldwise_init
struct FinishStored(Unary, Copyable):
    """After the sleep: count the completion, then produce the ResultT payload."""
    var done: Ref[Int]
    var payload: Stored
    comptime Arg = NoneType
    comptime Out = IO[Result[Int, String], Int]
    comptime Error = Never

    def call(self, var unit: NoneType) -> IO[Result[Int, String], Int]:
        return self.done.update[Int](inc).map(self.payload.copy())


@fieldwise_init
struct Maybe(Unary, Copyable):
    """OptionalT elements: `absent_at` is absent at once, `failing` raises the base error at once; the rest sleep 50 ms.

    Sleeping elements count their completion in `done` and their finalizer in `finalized`.
    """
    var done: Ref[Int]
    var finalized: Ref[Int]
    var absent_at: Int
    var failing: Int
    comptime Arg = Int
    comptime Out = IO[Optional[Int], Int]
    comptime Error = Never

    def call(self, var index: Int) -> IO[Optional[Int], Int]:
        if index == self.absent_at:
            return IO[Optional[Int], Int].pure(Optional[Int]())
        if index == self.failing:
            return IO[Optional[Int], Int].raise_error(index)
        return IO[NoneType, Int].sleep(ms(50)).flat_map(FinishPresent(self.done.copy(), Present(index * 3))).guarantee(self.finalized.update[Int](inc))


@fieldwise_init
struct Either(Unary, Copyable):
    """ResultT elements: element 3 stores an error at once, element 1 after its 50 ms sleep; the rest succeed after 50 ms."""
    var done: Ref[Int]
    comptime Arg = Int
    comptime Out = IO[Result[Int, String], Int]
    comptime Error = Never

    def call(self, var index: Int) -> IO[Result[Int, String], Int]:
        if index == 3:
            return IO[Result[Int, String], Int].pure(Result[Int, String](Err(String("e3"))))
        return IO[NoneType, Int].sleep(ms(50)).flat_map(FinishStored(self.done.copy(), Stored(index, index == 1)))


def cells() -> Tuple[Ref[Int], Ref[Int]]:
    return (Ref[Int](0), Ref[Int](0))


def present_in_order() raises:
    var c = cells()
    var control = TestControl(par_traverse[OP](indices(10), Maybe(c[0].copy(), c[1].copy(), -1, -1)))
    control.tick_all()
    check(since_zero(control.now()) == 50_000_000, "ten 50 ms elements overlap")
    var values = success(control^.results())
    check(Bool(values) and len(values.value()) == 10, "every element is present")
    for index in range(10):
        check(values.value()[index] == index * 3, "results keep source order")


def absence_runs_the_rest() raises:
    var c = cells()
    var control = TestControl(par_traverse[OP](indices(10), Maybe(c[0].copy(), c[1].copy(), 1, -1)))
    control.tick_all()
    check(control.is_completed(), "the traversal completes")
    check(since_zero(control.now()) == 50_000_000, "an absence at 0 ms stops nothing: the rest finish at 50 ms")
    check(not success(control^.results()), "any absence makes the result absent")
    check(count_of(c[0]) == 9, "later elements' effects run after the early absence")
    check(count_of(c[1]) == 9, "every finalizer runs exactly once")


def base_failure_stops_the_rest() raises:
    var c = cells()
    var control = TestControl(par_traverse[OP](indices(10), Maybe(c[0].copy(), c[1].copy(), -1, 7)))
    control.tick_all()
    check(since_zero(control.now()) == 0, "a base failure stops the sleeping elements at once")
    var outcome = control^.results()
    check(Bool(outcome) and outcome.value().is_err(), "the base failure is the IO's failure")
    check(count_of(c[0]) == 0, "no stopped element completed")
    check(count_of(c[1]) == 9, "every started element's finalizer runs exactly once")


def cancel_drains() raises:
    var c = cells()
    var control = TestControl(par_traverse[OP](indices(8), Maybe(c[0].copy(), c[1].copy(), -1, -1)))
    control.tick()
    check(not control.is_completed(), "every element sleeps")
    control.request_cancel()
    control.tick_all()
    check(control.is_completed() and since_zero(control.now()) == 0, "cancellation completes without waiting")
    check(not control^.results(), "the traversal is canceled")
    check(count_of(c[1]) == 8 and count_of(c[0]) == 0, "canceling drains every child, finalizing each once")


def first_stored_error_in_element_order() raises:
    var done = Ref[Int](0)
    var control = TestControl(par_traverse[RP](indices(6), Either(done.copy())))
    control.tick_all()
    check(since_zero(control.now()) == 50_000_000, "a stored error at 0 ms stops nothing")
    var stored = success(control^.results())
    check(stored.is_err() and stored._err().value == "e1", "the first stored error in element order, not in time order")
    check(count_of(done) == 5, "every other element ran to completion")


def bounded_and_void() raises:
    var c = cells()
    var control = TestControl(par_traverse_n[OP](2, indices(6), Maybe(c[0].copy(), c[1].copy(), 0, -1)))
    control.tick_all()
    check(since_zero(control.now()) == 150_000_000, "two at a time: five 50 ms elements take 150 ms")
    check(not success(control^.results()), "par_traverse_n: absent")
    check(count_of(c[0]) == 5, "par_traverse_n runs every element after the absence")
    var d = cells()
    var voided = TestControl(par_traverse_void[OP](indices(6), Maybe(d[0].copy(), d[1].copy(), 2, -1)))
    voided.tick_all()
    check(not success(voided^.results()), "par_traverse_void: absent")
    check(count_of(d[0]) == 5, "par_traverse_void runs every element")
    var f = cells()
    var listed = TestControl(iter_par_traverse[OP](indices(4), Maybe(f[0].copy(), f[1].copy(), 3, -1)))
    listed.tick_all()
    check(since_zero(listed.now()) == 50_000_000, "fp.iteration.par_traverse runs concurrently")
    check(not success(listed^.results()) and count_of(f[0]) == 3, "fp.iteration.par_traverse: absent after every element ran")
    var stored = List[IO[Result[Int, String], Int]]()
    for index in range(3):
        stored.append(Either(Ref[Int](0)).call(index))
    var sequenced = TestControl(iter_par_sequence[RP](stored^))
    sequenced.tick_all()
    var seq = success(sequenced^.results())
    check(seq.is_err() and seq._err().value == "e1", "fp.iteration.par_sequence keeps the first stored error")
    var e = cells()
    var voided_n = TestControl(par_traverse_void_n[OP](3, indices(6), Maybe(e[0].copy(), e[1].copy(), -1, -1)))
    voided_n.tick_all()
    check(since_zero(voided_n.now()) == 100_000_000, "par_traverse_void_n: three at a time")
    check(Bool(success(voided_n^.results())), "par_traverse_void_n: present")


def sequence_and_fluent() raises:
    var c = cells()
    var element = Maybe(c[0].copy(), c[1].copy(), 0, -1)
    var programs = List[IO[Optional[Int], Int]]()
    for index in range(4):
        programs.append(element.call(index))
    var control = TestControl(par_sequence[OP](programs^))
    control.tick_all()
    check(since_zero(control.now()) == 50_000_000, "par_sequence: concurrent")
    check(not success(control^.results()), "par_sequence: absent")
    check(count_of(c[0]) == 3, "par_sequence runs every program")
    var product = TestControl(pipeline[OP](element.call(0)).par_product_n((element.call(1),)).get())
    product.tick_all()
    check(since_zero(product.now()) == 50_000_000, "pipeline[OptionalT].par_product_n runs both concurrently")
    check(not success(product^.results()), "pipeline[OptionalT].par_product_n is absent")
    check(count_of(c[0]) == 4, "the right operand ran after the left's absence")
    var paired = TestControl(pipeline[RP](Either(Ref[Int](0)).call(2)).par_product_n((Either(Ref[Int](0)).call(4),)).get())
    paired.tick_all()
    check(since_zero(paired.now()) == 50_000_000, "pipeline[ResultT].par_product_n runs both operands concurrently")
    var pair = success(paired^.results())
    check(pair.is_ok() and pair._ok().value[0] == 6 and pair._ok().value[1] == 12, "pipeline[ResultT].par_product_n pairs Ok payloads")


def main() raises:
    present_in_order()
    absence_runs_the_rest()
    base_failure_stops_the_rest()
    cancel_drains()
    first_stored_error_in_element_order()
    bounded_and_void()
    sequence_and_fluent()
    print("par layers: OptionalT and ResultT run every element and settle absent or on the first stored error; base failure and cancellation drain")
