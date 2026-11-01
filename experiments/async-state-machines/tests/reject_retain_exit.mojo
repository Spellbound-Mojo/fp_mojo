# error: cannot implicitly convert
from fp.effects import ExitCase, IOContext
from state_machine import ScopedMachine, Step
@fieldwise_init
struct Keep(ScopedMachine):
    var saved: Optional[Pointer[ExitCase[Int], ImmUntrackedOrigin]]
    comptime Input = ExitCase[Int]
    comptime Value = NoneType
    comptime Error = Int
    def poll[o: ImmOrigin](mut self, ref[o] exit: Self.Input, context: IOContext[Int]) -> Step[NoneType, Int]:
        self.saved = Optional(Pointer(to=exit))
        return .ready(None)
def main():
    _ = Keep(None)
