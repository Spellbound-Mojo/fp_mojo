# error: no matching function in call to 'run_layer'
from fp.callables import OnceThunk
from fp.effects import ReaderT, LiftDefer, defer, lift, run as run_layer
from fp.effects.async_runtime import IO, Async

comptime RT = ReaderT[Async[Int], List[Int]]


@fieldwise_init
struct Build(OnceThunk):
    comptime Out = type_of(lift[RT](IO[Int, Int].pure(1)))
    comptime Error = Never

    def call_once(deinit self) -> Self.Out:
        return lift[RT](IO[Int, Int].pure(1))


def main() raises:
    # Deferring binds in ReaderT; over Async the bind would keep the borrowed environment.
    var env = List[Int]([7])
    _ = run_layer[RT](defer[LiftDefer[RT, Async[Int]]](Build()), env)
