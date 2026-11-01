# error: cannot implicitly convert
from fp.effects import ScopedIO, ExitCase, IO, DelayContract, delay, guarantee_case, run_io
from fp.callables import OnceThunk
from fp.algebra import pure

@fieldwise_init
struct EscapedExitTask[o: ImmOrigin](OnceThunk):
    var pointer: Pointer[ExitCase[Int], Self.o]
    comptime Out = Pointer[ExitCase[Int], ImmUntrackedOrigin]
    def call_once(deinit self) -> Self.Out:
        return self.pointer

@fieldwise_init
struct EscapedExit(ScopedIO):
    comptime Input = ExitCase[Int]
    comptime Value = Pointer[ExitCase[Int], ImmUntrackedOrigin]
    comptime Error = Int
    comptime Action[o: ImmOrigin] = DelayContract[EscapedExitTask[o], Int].Out
    def build[o: ImmOrigin](deinit self, ref[o] value: Self.Input) -> Self.Action[o]:
        return delay[Int](EscapedExitTask(Pointer(to=value)))

def main():
    _ = run_io(guarantee_case(pure[IO[Int]](1), EscapedExit()))
