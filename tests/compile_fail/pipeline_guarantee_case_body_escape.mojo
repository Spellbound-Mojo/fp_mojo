from fp.functions import pipeline
# error: cannot implicitly convert
from fp.effects.io import delay
from fp.effects import IO, ExitCase
from fp.algebra import pure
def cleanup(exit: ExitCase[Error]) -> IO[Error].Pure[Int]: return pure[IO[Error]](1)
from fp.effects.outcomes import Outcome
from fp.callables import OnceThunk
@fieldwise_init
struct Borrowed[o: ImmOrigin](OnceThunk):
    var owner: Pointer[List[Int], Self.o]
    comptime Out = Span[Int, Self.o]
    def call_once(deinit self) -> Self.Out: return Span(self.owner[])
def escape() -> Outcome[Span[Int, ImmUntrackedOrigin], Error]:
    var owner = List[Int]([1])
    return pipeline(delay[Error](Borrowed(Pointer(to=owner)))).guarantee_case(cleanup).run_io()
def main():
    _ = escape()
