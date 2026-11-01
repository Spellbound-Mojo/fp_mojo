"""One generic program, several stacks, and explicit Reader selection."""
from fp.effects import Ask, LiftLocal, Reader, ReaderT, StateT, ask, local, run


def read_config[C: Ask]() raises C.AskError -> C.Asked where C.AskAvailable:
    return ask[C]()


def increase(value: Int) -> Int: return value + 3


def main():
    comptime R = Reader[Int]
    var environment = 5
    print("reader config:", run[R](read_config[R](), environment))

    comptime S = StateT[R, Int]
    comptime C = LiftLocal[S, R]
    var computation = local[C](read_config[C](), increase)
    var reader = run[S](computation^, 42)
    var result = run[R](reader^, environment)
    print("scoped config:", result[0], "; state:", result[1])
    print("environment after scope:", environment)

    # Both Readers use Int, so selecting by type would be ambiguous.
    comptime Two = ReaderT[R, Int]
    comptime Inner = LiftLocal[Two, R]
    var inner = run[Two](read_config[Inner](), 100)
    print("inner config:", run[R](inner^, environment))
    var outer = run[Two](read_config[Two](), 100)
    print("outer config:", run[R](outer^, environment))
