# error: cannot implicitly convert 'Optional[Pointer[String, p]]' value to 'Optional[Pointer[String, o]]'
from state_machine import ScopedMachine, Step, Wait
from fp.effects import IOContext, CancellationToken


@fieldwise_init
struct Retain[o: ImmOrigin](ScopedMachine):
    var saved: Optional[Pointer[String, Self.o]]
    comptime Input = String
    comptime Value = Int
    comptime Error = Int

    def poll[p: ImmOrigin](mut self, ref[p] value: String, context: IOContext[Int]) -> Step[Int, Int]:
        self.saved = Optional(Pointer(to=value))
        return Step[Int, Int].pending(Wait())


def main():
    var use = Retain[ImmUntrackedOrigin](None)
    var owner = String("scoped")
    _ = use.poll(owner, IOContext[Int](CancellationToken(), False))
