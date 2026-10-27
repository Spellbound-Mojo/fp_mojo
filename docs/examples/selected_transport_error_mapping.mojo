"""Rebind stored errors while preserving deferred execution, state and logs."""
from fp.algebra import ResultFamily, StringMonoid, ApplicativeError
from fp.effects import ReaderT, StateT, WriterT, run, writer, run_writer
from fp.data import Result, Ok
from fp.functions import pipeline


@fieldwise_init
struct StateValue(Movable):
    var value: Int


def display(var value: Int) -> String: return String(value)
def error_code(var error: String) -> Int: return error.byte_length()


def main():
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
    print("reader error:", observed._err().value, "; calls:", calls)

    comptime S = StateT[ResultFamily[String],StateValue]
    comptime S2 = StateT[ResultFamily[Int],StateValue]
    comptime assert not conforms_to(S,ApplicativeError)
    var state_action = pipeline[S](S.pure(4)).map_both(display,error_code)
    comptime assert type_of(state_action).I == S2
    var state_result = run[S2](state_action^.get(),StateValue(9))
    print("state:", state_result._ok().value[0], state_result._ok().value[1].value)

    comptime W = WriterT[ResultFamily[String],StringMonoid]
    comptime W2 = WriterT[ResultFamily[Int],StringMonoid]
    var base = Result[Tuple[String,Int],String](Ok(Tuple(String("saved"),5)))
    var logged = pipeline[W](writer[W,Int](base^)).map_both(display,error_code)
    comptime assert type_of(logged).I == W2
    var writer_result = run_writer[W2](logged^.get())
    print("writer:", writer_result._ok().value[0], writer_result._ok().value[1])
