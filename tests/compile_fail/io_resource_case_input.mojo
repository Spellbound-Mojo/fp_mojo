# error: violated constraint
from fp.effects import IO, ScopedIO, resource_io_case
from fp.algebra import pure

@fieldwise_init
struct WrongCase(ScopedIO):
    comptime Input = Int
    comptime Value = Int
    comptime Error = Int
    comptime Action[o: ImmOrigin] = IO[Int].Pure[Int]
    def build[o: ImmOrigin](deinit self, ref[o] value: Int) -> Self.Action[o]:
        return pure[IO[Int]](value)

def release(var value: Int) -> WrongCase:
    return WrongCase()

def main():
    _ = resource_io_case(pure[IO[Int]](1), release)
