# error: cannot implicitly convert
from fp.effects.io import delay, run_io
from fp.effects.outcomes import Outcome
from fp.callables import OnceThunk
@fieldwise_init
struct Borrowed[o: ImmOrigin](OnceThunk):
    var owner: Pointer[List[Int], Self.o]
    comptime Out = Span[Int, Self.o]
    def call_once(deinit self) -> Self.Out: return Span(self.owner[])
def escape() -> Outcome[Span[Int, ImmUntrackedOrigin], Error]:
    var owner = List[Int]([1])
    return run_io(delay[Error](Borrowed(Pointer(to=owner))))
def main():
    _ = escape()
