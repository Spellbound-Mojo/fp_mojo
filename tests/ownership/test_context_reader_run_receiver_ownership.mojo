from fp.callables import MutableUnary, RepeatableUnary, call_once, call_repeated
from fp.effects import Reader, ReaderAction
from fp.effects.reader import _ReaderContinue
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Owner(Movable):
    var id: Int
    var trace: ArcPointer[String]
    def __deinit__(deinit self):
        self.trace[] += String(self.id)

@fieldwise_init
struct Action[fail: Bool](ReaderAction):
    var value: Owner
    var record: Owner
    comptime Family = Reader[Int]
    comptime Env = Int
    comptime Value = Owner
    comptime Out[o: ImmOrigin] = Owner
    comptime Error[o: ImmOrigin] = Int
    def run[o: ImmOrigin](deinit self, ref[o] env: Int) raises Int -> Owner:
        self.record.trace[] += "r" + String(env)
        if Self.fail:
            raise 83
        return self.value^

@fieldwise_init
struct Produce[fail: Bool, run_fail: Bool](MutableUnary):
    var capture: Owner
    var calls: Int
    comptime Arg = Owner
    comptime Out = Action[Self.run_fail]
    comptime Error = Int
    def call_mut(mut self, var value: Owner) raises Int -> Self.Out:
        self.calls += 1
        self.capture.trace[] += "f" + String(self.calls)
        if Self.fail:
            raise 71
        return Self.Out(value^, Owner(3, self.capture.trace))

def exercise[repeated: Bool, fail: Bool, run_fail: Bool, o: ImmOrigin](ref[o] env: Int) raises:
    var trace = ArcPointer(String())
    comptime F = Produce[fail, run_fail]
    comptime C = _ReaderContinue[Reader[Int], F, Int, o]
    comptime assert RepeatableUnary[C] and not conforms_to(C, Copyable)
    var continuation = C(F(Owner(5, trace), 0), Pointer(to=env))
    var code = 0
    comptime if repeated:
        for _ in range(2):
            try:
                var result = call_repeated(continuation, Owner(1, trace))
                _ = result^
            except error:
                comptime assert type_of(error) == Int
                code = error
        _ = continuation^
    else:
        try:
            var result = call_once(continuation^, Owner(1, trace))
            _ = result^
        except error:
            comptime assert type_of(error) == Int
            code = error
    assert_equal(code, 71 if fail else 83 if run_fail else 0)
    var expected: String
    if fail:
        expected = "f11f215" if repeated else "f115"
    else:
        expected = "f1r731f2r7315" if repeated else "f15r731"
    assert_equal(trace[], expected)

def main() raises:
    var env = 7
    exercise[False, False, False](env)
    exercise[False, True, False](env)
    exercise[False, False, True](env)
    exercise[False, True, True](env)
    exercise[True, False, False](env)
    exercise[True, True, False](env)
    exercise[True, False, True](env)
    exercise[True, True, True](env)
