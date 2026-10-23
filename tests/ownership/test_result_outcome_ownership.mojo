"""Outcome combinators move selected payloads and dispose of skipped owners."""
from fp.data import Result, Ok, Err
from fp.functions import piped
from fp.callables import OnceUnary, BorrowOnceCallable
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true


@fieldwise_init
struct ROOOwner(Movable):
    var name: String
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


def roo_name(var value: ROOOwner) -> String: return value.name.copy()


@fieldwise_init
struct ROOBranch(OnceUnary):
    var output: ROOOwner
    var throws: Bool
    comptime Arg = ROOOwner
    comptime Out = ROOOwner
    comptime Error = ROOOwner
    def call_once(deinit self, var input: ROOOwner) raises ROOOwner -> ROOOwner:
        if self.throws: raise self.output^
        return self.output^


@fieldwise_init
struct ROOSequence(OnceUnary):
    var branch: ROOBranch
    comptime Arg = ROOOwner
    comptime Out = Result[ROOOwner, ROOOwner]
    comptime Error = ROOOwner
    def call_once(deinit self, var input: ROOOwner) raises ROOOwner -> Self.Out:
        return Err(self.branch^.call_once(input^))


@fieldwise_init
struct ROOObserve(BorrowOnceCallable):
    var output: ROOOwner
    var mode: Int
    var observed: ArcPointer[Int]
    comptime Payload = Result[ROOOwner, ROOOwner]
    comptime Result = Result[ROOOwner, ROOOwner]
    comptime Failure = ROOOwner
    def invoke_once(deinit self, ref value: Self.Payload) raises ROOOwner capturing -> Self.Result:
        self.observed[] += 1 if value.is_ok() else 10
        if self.mode == 2: raise self.output^
        if self.mode == 1: return Err(self.output^)
        return Ok(self.output^)


def roo_branches() raises:
    for mode in range(3):
        for branch in range(4):
            var inputs = ArcPointer(0)
            var successes = ArcPointer(0)
            var errors = ArcPointer(0)
            var input = ROOOwner("original", inputs)
            var source = Result[ROOOwner, ROOOwner](Ok(input^)) if branch % 2 == 0 else Result[ROOOwner, ROOOwner](Err(input^))
            var ok = ROOBranch(ROOOwner("success", successes), branch >= 2)
            var err = ROOBranch(ROOOwner("error", errors), branch >= 2)
            var ok_drops = -1
            var err_drops = -1
            var is_ok = False
            var name: String
            try:
                var result: Result[ROOOwner, ROOOwner]
                if mode == 0: result = source^.map_both(ok^, err^)
                elif mode == 1: result = piped(source^).redeem(ok^, err^).get()
                else: result = source^.redeem_with(ROOSequence(ok^), ROOSequence(err^))
                is_ok = result.is_ok()
                ok_drops = successes[]
                err_drops = errors[]
                name = result^.fold_owned(roo_name, roo_name)
            except raised: name = raised.name.copy()
            assert_equal(name, "success" if branch % 2 == 0 else "error")
            if branch < 2:
                assert_equal(ok_drops, 0 if branch == 0 else 1)
                assert_equal(err_drops, 1 if branch == 0 else 0)
                assert_equal(is_ok, mode == 1 or (mode == 0 and branch == 0))
            assert_equal(inputs[], 1)
            assert_equal(successes[], 1)
            assert_equal(errors[], 1)


def roo_observation() raises:
    for mode in range(3):
        for branch in range(2):
            var inputs = ArcPointer(0)
            var outputs = ArcPointer(0)
            var observed = ArcPointer(0)
            var input = ROOOwner("original", inputs)
            var source = Result[ROOOwner, ROOOwner](Ok(input^)) if branch == 0 else Result[ROOOwner, ROOOwner](Err(input^))
            var input_drops = -1
            var output_drops = -1
            var is_ok = False
            var name: String
            try:
                var result = piped(source^).attempt_tap(ROOObserve(ROOOwner("observer", outputs), mode, observed)).get()
                input_drops = inputs[]
                output_drops = outputs[]
                is_ok = result.is_ok()
                name = result^.fold_owned(roo_name, roo_name)
            except raised: name = raised.name.copy()
            assert_equal(observed[], 1 if branch == 0 else 10)
            assert_equal(name, "original" if mode == 0 else "observer")
            if mode < 2:
                assert_equal(input_drops, mode)
                assert_equal(output_drops, 1 - mode)
                assert_equal(is_ok, mode == 0 and branch == 0)
            assert_equal(inputs[], 1)
            assert_equal(outputs[], 1)


@fieldwise_init
struct ROOSwap[A: Movable & Deinitable, B: Movable & Deinitable](OnceUnary):
    var output: Self.B
    comptime Arg = Self.A
    comptime Out = Self.B
    def call_once(deinit self, var value: Self.A) -> Self.B: return self.output^


@fieldwise_init
struct ROOPacket[A: Movable & Deinitable, B: Movable & Deinitable](Movable):
    var original: Self.A
    var output: Self.B
    def take(deinit self) -> Self.B: return self.output^


def roo_project[A: Movable & Deinitable, B: Movable & Deinitable](var packet: ROOPacket[A, B]) -> B:
    return packet^.take()


def roo_origins(left: List[Int], right: List[Int]) raises:
    var a = Span(left)
    var b = Span(right)
    comptime A = type_of(a)
    comptime B = type_of(b)
    for branch in range(2):
        var source = Result[A, B](Ok(a)) if branch == 0 else Result[A, B](Err(b))
        var mapped = source^.map_both(ROOSwap[A, B](b), ROOSwap[B, A](a))
        comptime assert type_of(mapped) == Result[B, A]
        def roo_read_left(var value: A) -> Int: return value[0]
        def roo_read_right(var value: B) -> Int: return value[0]
        assert_equal(mapped^.fold_owned(roo_read_right, roo_read_left), 9 if branch == 0 else 7)
        comptime P = ROOPacket[A, B]
        comptime Q = ROOPacket[B, A]
        var packet = Result[P, Q](Ok(P(a, b))) if branch == 0 else Result[P, Q](Err(Q(b, a)))
        var native_mapped = packet^.map_both(roo_project[A, B], roo_project[B, A])
        comptime assert type_of(native_mapped) == Result[B, A]
        assert_equal(native_mapped^.fold_owned(roo_read_right, roo_read_left), 9 if branch == 0 else 7)
    var drops = ArcPointer(0)
    var capture = ROOOwner("native", drops)
    def roo_captured(value: Int) {var capture^} -> Int:
        return value + capture.name.byte_length()
    var capture_input = Result[Int, Int](Ok(4))
    assert_equal(capture_input^.redeem(roo_captured, roo_captured).raise_on_err(), 10)
    assert_equal(drops[], 0)
    _ = roo_captured^
    assert_equal(drops[], 1)
    def roo_inspect(value: Result[A, B]) -> Result[Int, B]: return Ok(0)
    var retained = Result[A, B](Err(b)).attempt_tap(roo_inspect)
    comptime assert type_of(retained) == Result[A, B]
    assert_true(retained.is_err())
    def roo_read_a(var value: A) -> Int: return value[0]
    def roo_read_b(var value: B) -> Int: return value[0]
    assert_equal(retained^.fold_owned(roo_read_a, roo_read_b), 9)


def main() raises:
    roo_branches()
    roo_observation()
    var left: List[Int] = [7]
    var right: List[Int] = [9]
    roo_origins(left, right)
