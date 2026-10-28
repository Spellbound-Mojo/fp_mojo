# error: ScopedIO action must preserve the declared value and error
from fp.effects import IO, ScopedIO, ExitCase, guarantee_case, run_io
from fp.algebra import pure

@fieldwise_init
struct WrongFinalizerValue(ScopedIO):
    comptime Input = ExitCase[Int]
    comptime Value = String
    comptime Error = Int
    comptime Action[o: ImmOrigin] = IO[Int].Pure[Int]
    def build[o: ImmOrigin](deinit self, ref[o] value: Self.Input) -> Self.Action[o]:
        return pure[IO[Int]](1)

def main():
    _ = run_io(guarantee_case(pure[IO[Int]](1), WrongFinalizerValue()))
