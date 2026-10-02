"""Consuming Result callbacks: selection, native failures and owner cleanup."""
from fp.algebra import map, flat_map, ResultFamily
from std.builtin.rebind import rebind_var
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true
from fp.callables import Unary, OnceUnary, BorrowOnceCallable, invoke_borrowed_once
from fp.data import Result, Ok, Err
from test_attempt_once import Trace, Token, expected_ok


@fieldwise_init
struct Transform(OnceUnary):
    var state: Token[1]
    var fail: Bool
    comptime Arg = Token[2]
    comptime Out = Token[2]
    comptime Error = Token[2]
    def call_once(deinit self, var value: Token[2]) raises Token[2] -> Token[2]:
        self.state.trace[].calls += 1
        value.value += self.state.value
        if self.fail:
            raise value^
        return value^


@fieldwise_init
struct Sequence(OnceUnary):
    var transform: Transform
    var stored_error: Bool
    comptime Arg = Token[2]
    comptime Out = Result[Token[2], Token[2]]
    comptime Error = Token[2]
    def call_once(deinit self, var value: Token[2]) raises Token[2] -> Result[Token[2], Token[2]]:
        var transform = self.transform^
        var output = transform^.call_once(value^)
        if self.stored_error:
            return Result[Token[2], Token[2]](Err(output^))
        return Result[Token[2], Token[2]](Ok(output^))


@fieldwise_init
struct Read(BorrowOnceCallable):
    var state: Token[1]
    var fail: Bool
    comptime Payload = Token[2]
    comptime Result = Int
    comptime Failure = Token[2]
    def invoke_once(deinit self, ref payload: Self.Payload) raises Self.Failure capturing -> Int:
        self.state.trace[].calls += 1
        var value = payload.value + self.state.value
        if self.fail:
            raise Token[2](value, self.state.trace)
        return value


@fieldwise_init
struct Dual(Unary, OnceUnary, ImplicitlyCopyable):
    comptime Arg = Int
    comptime Out = Int
    def call(self, var value: Int) -> Int:
        return 1
    def call_once(deinit self, var value: Int) -> Int:
        return 2


@fieldwise_init
struct Stop(OnceUnary):
    comptime Arg = Int
    comptime Out = Int
    comptime Error = StopIteration
    def call_once(deinit self, var value: Int) raises StopIteration -> Int:
        raise StopIteration()


@fieldwise_init
struct BorrowPure(BorrowOnceCallable):
    var offset: Int
    comptime Payload = Int
    comptime Result = Int
    def invoke_once(deinit self, ref payload: Int) raises Never capturing -> Int:
        return payload + self.offset


@fieldwise_init
struct BorrowStop(BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = Int
    comptime Failure = StopIteration
    def invoke_once(deinit self, ref payload: Int) raises StopIteration capturing -> Int:
        raise StopIteration()


@fieldwise_init
struct External[origin: ImmOrigin](BorrowOnceCallable):
    var pointer: Pointer[String, Self.origin]
    var fail: Bool
    comptime Payload = Int
    comptime Result = Pointer[String, Self.origin]
    comptime Failure = Pointer[String, Self.origin]
    def invoke_once(deinit self, ref payload: Int) raises Self.Failure capturing -> Self.Result:
        if self.fail:
            raise self.pointer
        return self.pointer


@fieldwise_init
struct ExternalOwned[origin: ImmOrigin](OnceUnary):
    var function: External[Self.origin]
    comptime Arg = Int
    comptime Out = Pointer[String, Self.origin]
    comptime Error = Pointer[String, Self.origin]
    def call_once(deinit self, var value: Int) raises Self.Error -> Self.Out:
        # The external receiver ignores its input; no borrowed input escapes.
        if self.function.fail:
            raise self.function.pointer
        return self.function.pointer


def forward[F: OnceUnary, T: Movable & Deinitable, E: Movable & Deinitable](
    var subject: Result[T,E], var function: F
) raises F.Error -> Result[F.Out, E] where F.Arg == T:
    return map[ResultFamily[E]](function^, subject^)


def outer[F: OnceUnary, T: Movable & Deinitable, E: Movable & Deinitable](
    var subject: Result[T,E], var function: F
) raises F.Error -> Result[F.Out, E] where F.Arg == T:
    return forward(subject^, function^)


def forward_error[F: OnceUnary, T: Movable & Deinitable, E: Movable & Deinitable](
    var subject: Result[T,E], var function: F
) raises F.Error -> Result[T,F.Out] where F.Arg == E:
    return subject^.map_err(function^)


def forward_then[U: Movable & Deinitable, F: OnceUnary, T: Movable & Deinitable, E: Movable & Deinitable](
    var subject: Result[T,E], var function: F
) raises F.Error -> Result[U,E] where F.Arg == T and F.Out == Result[U,E]:
    # The where equality admits rebind; native conversion does not use it.
    return rebind_var[Result[U,E]](flat_map[ResultFamily[E]](function^, subject^))


def forward_else[U: Movable & Deinitable, F: OnceUnary, T: Movable & Deinitable, E: Movable & Deinitable](
    var subject: Result[T,E], var function: F
) raises F.Error -> Result[T,U] where F.Arg == E and F.Out == Result[T,U]:
    return rebind_var[Result[T,U]](subject^.or_else(function^))


def forward_borrow[T: Movable & Deinitable, E: Movable & Deinitable,
                   F: BorrowOnceCallable, G: BorrowOnceCallable](
    subject: Result[T,E], var on_ok: F, var on_err: G
) raises (G.Failure if F.Failure == Never else F.Failure) -> F.Result where F.Payload == T and G.Payload == E and F.Result == G.Result and (F.Failure == Never or G.Failure == Never or F.Failure == G.Failure):
    return subject.fold_once(on_ok^,on_err^)


def forward_owned[T: Movable & Deinitable, E: Movable & Deinitable, F: OnceUnary, G: OnceUnary](
    var subject: Result[T,E], var on_ok: F, var on_err: G
) raises (G.Error if F.Error == Never else F.Error) -> F.Out where F.Arg == T and G.Arg == E and F.Out == G.Out and (F.Error == Never or G.Error == Never or F.Error == G.Error):
    return subject^.fold_owned_once(on_ok^,on_err^)


def transformations() raises:
    comptime for op in range(4):
        for active in [False, True]:
            for fail in [False, True]:
                var trace = ArcPointer(Trace(0, SIMD[DType.int64,4](0)))
                var subject = Result[Token[2],Token[2]](Ok(Token[2](3,trace)))
                if active != (op == 0 or op == 2):
                    subject = Result[Token[2],Token[2]](Err(Token[2](3,trace)))
                var before = Int(trace[].drops[2])
                var caught = False
                var result_ok = False
                var callback_drops = 0
                var payload_drops = 0
                try:
                    var result: Result[Token[2],Token[2]]
                    var callback = Transform(Token[1](10,trace), fail)
                    comptime if op == 0:
                        result = outer(subject^, callback^)
                    elif op == 1:
                        result = forward_error(subject^,callback^)
                    elif op == 2:
                        result = forward_then[Token[2]](subject^,Sequence(callback^, False))
                    else:
                        result = forward_else[Token[2]](subject^,Sequence(callback^, False))
                    callback_drops = Int(trace[].drops[1])
                    payload_drops = Int(trace[].drops[2])
                    result_ok = result.is_ok()
                    _ = result^
                except error:
                    comptime assert type_of(error) == Token[2]
                    caught = True
                    assert_equal(error.value, 13)
                if not caught:
                    assert_equal(callback_drops, 1)
                    assert_equal(payload_drops, before)
                    assert_equal(result_ok, (op != 0 and op != 2) if not active else op != 1)
                assert_equal(caught, active and fail)
                assert_equal(trace[].calls, Int(active))
                assert_equal(trace[].drops[1], 1)
                assert_equal(Int(trace[].drops[2]), before + 1)


def eliminations() raises:
    for ok in [False, True]:
        for fail in [False, True]:
            var trace = ArcPointer(Trace(0, SIMD[DType.int64,4](0)))
            var subject = Result[Token[2],Token[2]](Ok(Token[2](3,trace)))
            if not ok:
                subject = Result[Token[2],Token[2]](Err(Token[2](3,trace)))
            var before = Int(trace[].drops[2])
            var caught = False
            var number: Int
            try:
                number = forward_borrow(subject,
                    Read(Token[1](10,trace), fail), Read(Token[1](20,trace), fail))
            except error:
                caught = True
                number = error.value
            assert_equal(number, 13 if ok else 23)
            assert_equal(caught, fail)
            assert_equal(trace[].calls, 1)
            assert_equal(trace[].drops[1], 2)
            assert_equal(Int(trace[].drops[2]), before + Int(fail))
            assert_equal(subject.is_ok(), ok)
            caught = False
            try:
                var result = forward_owned(subject^,
                    Transform(Token[1](30,trace), fail), Transform(Token[1](40,trace), fail))
                number = result.value
            except error:
                caught = True
                number = error.value
            assert_equal(number, 33 if ok else 43)
            assert_equal(caught, fail)
            assert_equal(trace[].calls, 2)
            assert_equal(trace[].drops[1], 4)
            assert_equal(Int(trace[].drops[2]), before + Int(fail) + 1)


def main() raises:
    transformations()
    eliminations()
    var dual = Dual()
    # One call prefers the consuming mode; fold_owned uses the shared one.
    assert_equal(map[ResultFamily[type_of(Result[Int,Int](Ok(4))).Error]](dual, Result[Int,Int](Ok(4))).fold_owned(dual,dual), 1)
    assert_equal(map[ResultFamily[type_of(Result[Int,Int](Ok(4))).Error]](dual^, Result[Int,Int](Ok(4))).fold_owned_once(Dual(),Dual()), 2)
    # Never is neutral in either branch; a callback StopIteration propagates.
    assert_equal(Result[Int,Int](Ok(4)).fold_owned_once(Dual(),Stop()), 2)
    assert_equal(Result[Int,Int](Err(4)).fold_owned_once(Stop(),Dual()), 2)
    var scalar = 4
    assert_equal(invoke_borrowed_once[Never](scalar,BorrowPure(5)), 9)
    assert_equal(Result[Int,Int](Ok(4)).fold_once(BorrowPure(5),BorrowPure(99)), 9)
    assert_equal(Result[Int,Int](Ok(4)).fold_once(BorrowPure(5),BorrowStop()), 9)
    assert_equal(Result[Int,Int](Err(4)).fold_once(BorrowStop(),BorrowPure(5)), 9)
    var caught_stop = False
    try:
        _ = Result[Int,Int](Ok(4)).fold_owned_once(Stop(),Dual())
    except error:
        comptime assert type_of(error) == StopIteration
        caught_stop = True
    assert_true(caught_stop)
    var trace = ArcPointer(Trace(0,SIMD[DType.int64,4](0)))
    var is_inner_error: Bool
    var dropped: Int
    try:
        var nested = map[ResultFamily[type_of(Result[Token[2],Token[2]](Ok(Token[2](1,trace)))).Error]](Sequence(Transform(Token[1](2,trace),False),True), Result[Token[2],Token[2]](Ok(Token[2](1,trace))))
        var inner = nested^.raise_on_err()
        is_inner_error = inner.is_err()
        _ = inner^
        dropped = Int(trace[].drops[2])
    except:
        raise Error('unexpected transformation failure')
    assert_true(is_inner_error)
    assert_equal(dropped, 1)
    var owner = String('surviving owner')
    var value = Result[Int,Int](Ok(7))
    var pointer: Pointer[String,ImmOrigin(origin_of(owner))]
    try:
        pointer = forward_borrow(value,
            External(Pointer(to=owner),False),External(Pointer(to=owner),False))
    except:
        raise Error("unexpected borrowed fold failure")
    assert_true(pointer == Pointer(to=owner))
    var wrapped: Result[Pointer[String,ImmOrigin(origin_of(owner))],Int]
    try:
        wrapped = outer(value^, ExternalOwned(External(Pointer(to=owner),False)))
    except:
        raise Error("unexpected owned mapper failure")
    var address = expected_ok(wrapped^)
    assert_true(address == Pointer(to=owner))
    var caught = False
    try:
        _ = outer(Result[Int,Int](Ok(0)), ExternalOwned(External(Pointer(to=owner),True)))
    except error:
        comptime assert type_of(error) == Pointer[String,ImmOrigin(origin_of(owner))]
        caught = True
        assert_true(error == Pointer(to=owner))
    assert_true(caught)
    print('result_once: ok')
