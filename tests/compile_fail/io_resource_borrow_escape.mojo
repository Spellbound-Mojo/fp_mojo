# error: cannot implicitly convert
from fp.effects import IO, ScopedIO, DelayContract, delay, eval_resource, run_io
from fp.callables import OnceThunk
from fp.algebra import pure

@fieldwise_init
struct EscapeResource[o: ImmOrigin](OnceThunk):
    var value: Pointer[String, Self.o]
    comptime Out = Pointer[String, ImmUntrackedOrigin]
    def call_once(deinit self) -> Self.Out:
        return self.value

@fieldwise_init
struct UseResource(ScopedIO):
    comptime Input = String
    comptime Value = Pointer[String, ImmUntrackedOrigin]
    comptime Error = Int
    comptime Action[o: ImmOrigin] = DelayContract[EscapeResource[o], Int].Out
    def build[o: ImmOrigin](deinit self, ref[o] value: String) -> Self.Action[o]:
        return delay[Int](EscapeResource(Pointer(to=value)))

def main():
    _ = run_io(eval_resource(pure[IO[Int]](String("scoped"))).use(UseResource()))
