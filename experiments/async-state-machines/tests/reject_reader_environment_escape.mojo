# error: no matching function in call to 'run_layer'
from fp.callables import OnceUnary
from fp.effects import ReaderT, ask, lift, run as run_layer
from fp.algebra import flat_map
from fp.effects.async_runtime import IO, Async

comptime R = ReaderT[Async[Int], List[Int]]


@fieldwise_init
struct ReadLater(OnceUnary):
    comptime Arg = Int
    comptime Out = type_of(ask[R]())

    def call_once(deinit self, var value: Int) -> Self.Out:
        return ask[R]()


def build() raises -> IO[List[Int], Int]:
    # The bind's continuation would keep a pointer to env inside the IO.
    var env = List[Int]([7, 7])
    var program = flat_map[R](lift[R](IO[Int, Int].pure(1)), ReadLater())
    return run_layer[R](program^, env)


def main() raises:
    _ = build()
