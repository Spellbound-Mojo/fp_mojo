"""Selected Writer capabilities, scoped laws and representation-preserving lifts."""
from fp.algebra import StringMonoid, ResultFamily, pure, flat_map, fail
from fp.effects import Tell, Listen, Censor, LiftTell, LiftListen, LiftCensor, Writer, WriterT, ReaderT, StateT, OptionalT, ResultT, writer, run_writer, run, tell, listen, censor
from fp.callables import Unary
from std.testing import assert_equal


@fieldwise_init
struct WCWrap(Unary, Copyable, Defaultable):
    comptime Arg = String
    comptime Out = String
    def call(self, var text: String) -> String: return "[" + text + "]"


def wc_emit[C: Tell](var text: C.Log.Value) raises C.TellError -> C.Told where C.TellAvailable:
    return tell[C](text^)


def wc_hear[C: Listen, V: Movable & Deinitable](var value: V) raises C.ListenError[V] -> C.Listened[V] where C.ListenCompatible[V]:
    return listen[C](value^)


def wc_scope[C: Censor, V: Movable & Deinitable](var value: V) raises C.CensorError[V, WCWrap] -> C.Censored[V, WCWrap] where C.Log.Value == String and C.CensorCompatible[V, WCWrap]:
    return censor[C](WCWrap(), value^)


def main() raises:
    comptime W = Writer[StringMonoid]
    var direct = run_writer[W](wc_hear[W](wc_scope[W](writer[W, Int](Tuple(String("a"), 7)))))
    assert_equal(direct[0], "[a]")
    assert_equal(direct[1][0], 7)
    assert_equal(direct[1][1], "[a]")
    var pure_log = run_writer[W](listen[W](pure[W](7)))
    assert_equal(pure_log[1][1], "")
    def next(var unused: NoneType) -> W.Told: return tell[W](String("b"))
    var ordered = run_writer[W](flat_map[W](next, wc_emit[W](String("a"))))
    assert_equal(ordered[0], "ab")
    # A scope affects only its argument, not preceding or following writes.
    def scoped_next(var unused: NoneType) -> type_of(wc_scope[W](tell[W](String("b")))):
        return wc_scope[W](tell[W](String("b")))
    assert_equal(run_writer[W](flat_map[W](scoped_next, tell[W](String("a"))))[0], "a[b]")
    def observed_next(var unused: NoneType) -> type_of(listen[W](tell[W](String("b")))):
        return listen[W](tell[W](String("b")))
    var scoped_read = run_writer[W](flat_map[W](observed_next, tell[W](String("a"))))
    assert_equal(scoped_read[0], "ab")
    assert_equal(scoped_read[1][1], "b")
    def same(var log: String) -> String: return log^
    assert_equal(run_writer[W](censor[W](same, tell[W](String("a"))))[0], "a")
    assert_equal(run_writer[W](wc_scope[W](wc_scope[W](tell[W](String("a")))))[0], "[[a]]")
    var heard_before_change = run_writer[W](wc_scope[W](listen[W](tell[W](String("a")))))
    assert_equal(heard_before_change[0], "[a]")
    assert_equal(heard_before_change[1][1], "a")

    comptime R = ReaderT[W, Int]
    comptime RC = LiftCensor[R, W]
    var reader = run_writer[W](run[R](wc_hear[RC](wc_scope[RC](wc_emit[RC](String("r")))), 9))
    assert_equal(reader[0], "[r]")
    assert_equal(reader[1][1], "[r]")
    var replay = wc_scope[RC](wc_emit[RC](String("r")))
    var copy = replay.copy()
    assert_equal(run_writer[W](run[R](copy^, 0))[0], "[r]")
    assert_equal(run_writer[W](run[R](replay^, 0))[0], "[r]")

    comptime S = StateT[W, Int]
    comptime SC = LiftCensor[S, W]
    var state = run_writer[W](run[S](wc_hear[SC](wc_scope[SC](wc_emit[SC](String("s")))), 42))
    assert_equal(state[0], "[s]")
    assert_equal(state[1][0][1], "[s]")
    assert_equal(state[1][1], 42)

    comptime Two = WriterT[W, StringMonoid]
    comptime Inner = LiftCensor[Two, W]
    var nested_value = writer[Two, Int](writer[W, Tuple[String, Int]](Tuple(String("inner"), Tuple(String("outer"), 8))))
    var inner = run_writer[W](run_writer[Two](wc_hear[Inner](wc_scope[Inner](nested_value^))))
    assert_equal(inner[0], "[inner]")
    assert_equal(inner[1][0], "outer")
    assert_equal(inner[1][1][0], 8)
    assert_equal(inner[1][1][1], "[inner]")
    var outer_value = writer[Two, Int](writer[W, Tuple[String, Int]](Tuple(String("inner"), Tuple(String("outer"), 8))))
    var outer = run_writer[W](run_writer[Two](wc_hear[Two](wc_scope[Two](outer_value^))))
    assert_equal(outer[0], "inner")
    assert_equal(outer[1][0], "[outer]")
    assert_equal(outer[1][1][1], "[outer]")

    comptime O = OptionalT[W]
    comptime OC = LiftCensor[O, W]
    var present = run_writer[W](wc_hear[OC](wc_scope[OC](wc_emit[OC](String("o")))))
    assert_equal(present[0], "[o]")
    assert_equal(present[1].value()[1], "[o]")
    var absent = writer[W, Optional[Int]](Tuple(String("kept"), Optional[Int]()))
    var empty = run_writer[W](wc_hear[OC](wc_scope[OC](absent^)))
    assert_equal(empty[0], "[kept]")
    assert_equal(Bool(empty[1]), False)

    comptime T = ResultT[W, String]
    comptime TC = LiftCensor[T, W]
    var success = run_writer[W](wc_hear[TC](wc_scope[TC](wc_emit[TC](String("t")))))
    assert_equal(success[0], "[t]")
    assert_equal(success[1]._ok().value[1], "[t]")
    def fail_after(var unused: NoneType) -> type_of(fail[T, Int](String("stored"))):
        return fail[T, Int](String("stored"))
    var failed = run_writer[W](wc_hear[TC](wc_scope[TC](flat_map[T](fail_after, tell[TC](String("kept"))))))
    assert_equal(failed[0], "[kept]")
    assert_equal(failed[1]._err().value, "stored")
    # Reversing the stack loses the log on a stored failure.
    comptime Discard = WriterT[ResultFamily[String], StringMonoid]
    var discarded = run_writer[Discard](wc_hear[Discard](wc_scope[Discard](fail[Discard, Int](String("lost")))))
    assert_equal(discarded._err().value, "lost")

    comptime Deep = ResultT[S, String]
    comptime DC = LiftCensor[Deep, SC]
    var deep = run_writer[W](run[S](wc_hear[DC](wc_scope[DC](wc_emit[DC](String("deep")))), 77))
    assert_equal(deep[0], "[deep]")
    assert_equal(deep[1][0]._ok().value[1], "[deep]")
    assert_equal(deep[1][1], 77)
    var just_tell = run_writer[W](run[R](tell[LiftTell[R, W]](String("tell")), 0))
    assert_equal(just_tell[0], "tell")
    var just_listen = run_writer[W](run[R](listen[LiftListen[R, W]](tell[RC](String("listen"))), 0))
    assert_equal(just_listen[1][1], "listen")

    def reject(var text: String) raises Int -> String: raise text.byte_length()
    var code = 0
    try: _ = censor[TC](reject, tell[TC](String("abc")))
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 3)
    var skipped: Bool
    try:
        var rejected = run_writer[Discard](censor[Discard](reject, fail[Discard, Int](String("lost"))))
        skipped = rejected.is_err()
    except error:
        raise Error("censor must not run when the base has no log")
    assert_equal(skipped, True)
    var suffix = String("!")
    def append(var text: String) {suffix} -> String: return text + suffix
    assert_equal(run_writer[W](censor[W](append, wc_scope[W](tell[W](String("a")))))[0], "[a]!")
    print("Writer capabilities: scoped laws, explicit stacks and sum behavior")
