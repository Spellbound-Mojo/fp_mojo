"""External capability dictionaries and exact construction versus run errors."""
from fp.algebra import StringMonoid
from fp.effects import Tell, Listen, Censor, Writer, ReaderT, LiftCensor, tell, listen, censor, run, run_writer
from fp.callables import UnaryContract, Unary
from std.testing import assert_equal


@fieldwise_init
struct WCBuildError(Movable):
    var code: Int


struct WCChecked[reject: Bool](Censor):
    # This dictionary selects existing semantics without being a Writer family.
    comptime Family = Writer[StringMonoid]
    comptime Log = StringMonoid
    comptime TellAvailable = True
    comptime Told = Self.Family.Told
    comptime TellError = WCBuildError
    comptime ListenCompatible[V: Movable & Deinitable] = Self.Family.ListenCompatible[V]
    comptime Listened[V: Movable & Deinitable] = Self.Family.Listened[V]
    comptime ListenError[V: Movable & Deinitable] = WCBuildError
    comptime CensorCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Family.CensorCompatible[V, F]
    comptime Censored[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Family.Censored[V, F]
    comptime CensorError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Family.CensorError[V, F]
    @staticmethod
    def tell(var log: String) raises WCBuildError -> Self.Told:
        if Self.reject: raise WCBuildError(11)
        return Self.Family.tell(log^)
    @staticmethod
    def listen[V: Movable & Deinitable](var value: V) raises Self.ListenError[V] -> Self.Listened[V]:
        if Self.reject: raise WCBuildError(12)
        return Self.Family.listen(value^)
    @staticmethod
    def censor[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises Self.CensorError[V, F] -> Self.Censored[V, F]:
        return Self.Family.censor(f^, value^)


@fieldwise_init
struct WCGenericTag(Unary, Copyable, Defaultable):
    comptime Arg = String
    comptime Out = String
    def call(self, var log: String) -> String: return log + "!"


def wc_generic_tell[C: Tell](var log: C.Log.Value) raises C.TellError -> C.Told where C.TellAvailable:
    return tell[C](log^)


def wc_generic_listen[C: Listen, V: Movable & Deinitable](var value: V) raises C.ListenError[V] -> C.Listened[V] where C.ListenCompatible[V]:
    return listen[C](value^)


def wc_generic_censor[C: Censor, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
) raises C.CensorError[V, F] -> C.Censored[V, F] where C.CensorCompatible[V, F] and F.Arg == C.Log.Value and F.Out == C.Log.Value:
    return censor[C](value^, f^)


def main() raises:
    comptime W = Writer[StringMonoid]
    comptime R = ReaderT[W, Int]
    comptime Bad = LiftCensor[R, WCChecked[True]]
    var code = 0
    try: _ = wc_generic_tell[Bad](String("a"))
    except error:
        comptime assert type_of(error) == WCBuildError
        code = error.code
    assert_equal(code, 11)
    comptime C = LiftCensor[R, WCChecked[False]]
    var pending: C.Told
    try: pending = wc_generic_tell[C](String("a"))
    except error: raise Error("unexpected construction failure")
    var scoped_read = wc_generic_listen[C](wc_generic_censor[C](WCGenericTag(), pending^))
    var text: String
    var heard: String
    try:
        var result = run_writer[W](run[R](scoped_read^, 0))
        text = result[0]
        heard = result[1][1]
    except error: raise Error("unexpected listen failure")
    assert_equal(text, "a!")
    assert_equal(heard, "a!")
    var bad_read = listen[Bad](R.lift(tell[W](String("a"))))
    try: _ = run[R](bad_read^, 0)
    except error:
        comptime assert type_of(error) == WCBuildError
        code = error.code
    assert_equal(code, 12)

    var source: C.Told
    try: source = wc_generic_tell[C](String("abc"))
    except error: raise Error("unexpected construction failure")
    def reject(var log: String) raises Int -> String: raise log.byte_length()
    var scoped = censor[C](source^, reject)
    try: _ = run[R](scoped^, 0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 3)
    print("Writer capabilities: external dictionaries, generic contracts, native error phases")
