"""Select a log once and reuse the same scoped operations through a stack."""
from fp.algebra import StringMonoid, flat_map, fail
from fp.effects import Tell, Listen, Writer, ReaderT, StateT, ResultT, LiftCensor, tell, listen, censor, run, run_writer


def emit[C: Tell](var text: C.Log.Value) raises C.TellError -> C.Told where C.TellAvailable:
    return tell[C](text^)


def hear[C: Listen, V: Movable & Deinitable](var value: V) raises C.ListenError[V] -> C.Listened[V] where C.ListenCompatible[V]:
    return listen[C](value^)


def tag(var text: String) -> String: return "[" + text + "]"


def main():
    comptime W = Writer[StringMonoid]
    var direct = run_writer[W](hear[W](censor[W](tag, emit[W](String("saved")))))
    print("output:", direct[0], "; observed:", direct[1][1])

    comptime R = ReaderT[W, Int]
    comptime S = StateT[R, Int]
    comptime C = LiftCensor[S, LiftCensor[R, W]]
    var reader = run[S](hear[C](censor[C](tag, emit[C](String("nested")))), 42)
    var nested = run_writer[W](run[R](reader^, 5))
    print("nested output:", nested[0], "; observed:", nested[1][0][1], "; state:", nested[1][1])

    # ResultT over Writer retains its output even when the result is a failure.
    comptime T = ResultT[W, String]
    comptime TC = LiftCensor[T, W]
    def reject(var unused: NoneType) -> type_of(fail[T, Int](String("rejected"))):
        return fail[T, Int](String("rejected"))
    var failed = flat_map[T](reject, emit[TC](String("attempted")))
    var retained = run_writer[W](hear[TC](censor[TC](tag, failed^)))
    print("failed:", retained[1].is_err(), "; retained output:", retained[0])
