# error: cannot implicitly convert
from fp.callables import Thunk
from fp.data import Capture, Result, attempt_once
@fieldwise_init
struct View[o: ImmOrigin](Thunk):
    comptime Out = Pointer[String, Self.o]
    var pointer: Self.Out
    def call(self) -> Self.Out: return self.pointer
def wrong[o: ImmOrigin](ref[o] owner: String) -> Result[Pointer[String, o], Never]:
    var local = String("local")
    return Capture[String]().run(View(Pointer(to=local)))
def main(): pass
