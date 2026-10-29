from fp.functions import pipeline
# error: violated constraint
from fp.effects import IO, ScopedIO, ExitCase, guarantee_case
from fp.algebra import pure

@fieldwise_init
struct WrongFinalizerError(ScopedIO):
    comptime Input = ExitCase[String]
    comptime Value = Int
    comptime Error = String
    comptime Action[o: ImmOrigin] = IO[String].Pure[Int]
    def build[o: ImmOrigin](deinit self, ref[o] value: Self.Input) -> Self.Action[o]:
        return pure[IO[String]](1)

def main():
    _ = pipeline(pure[IO[Int]](1)).guarantee_case(WrongFinalizerError()).get()
