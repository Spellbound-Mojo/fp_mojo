"""Rebind stored errors while preserving deferred execution, state and logs."""
from fp.algebra import ResultFamily, StringMonoid, ApplicativeError
from fp.effects import ReaderT, StateT, WriterT, run, writer
from fp.data import Result, Ok
from fp.functions import pipeline


@fieldwise_init
struct StateValue(Movable):
    var value: Int


def display(var value: Int) -> String: return String(value)
def error_code(var error: String) -> Int: return error.byte_length()


def workflow() raises Int:
    comptime R = ReaderT[ResultFamily[String],Int]
    comptime R2 = ReaderT[ResultFamily[Int],Int]
    var calls = 0
    def counted(var error: String) {mut calls} -> Int:
        calls += 1
        return error.byte_length()
    var pending = pipeline[R](R.fail[Int](String("missing"))).map_err(counted)
    comptime assert type_of(pending).I == R2
    print("before run:", calls)
    var observed = run[R2](pending^.get(), 0)
    print("reader error:", observed^.swap().raise_on_err(), "; calls:", calls)

    comptime S = StateT[ResultFamily[String],StateValue]
    comptime S2 = StateT[ResultFamily[Int],StateValue]
    comptime assert not conforms_to(S,ApplicativeError)
    var state_action = pipeline[S](S.pure(4)).map_both(display,error_code)
    comptime assert type_of(state_action).I == S2
    var state_result = run[S2](state_action^.get(),StateValue(9)).raise_on_err()
    print("state:", state_result[0], state_result[1].value)

    comptime W = WriterT[ResultFamily[String],StringMonoid]
    comptime W2 = WriterT[ResultFamily[Int],StringMonoid]
    var base = Result[Tuple[String,Int],String](Ok(Tuple(String("saved"),5)))
    var logged = pipeline[W](writer[W,Int](base^)).map_both(display,error_code)
    comptime assert type_of(logged).I == W2
    var writer_result = run[W2](logged^.get()).raise_on_err()
    print("writer:", writer_result[0], writer_result[1])


def main() raises:
    try: workflow()
    except code: raise Error("unexpected error code: " + String(code))
