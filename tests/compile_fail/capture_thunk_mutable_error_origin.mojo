# error: cannot implicitly convert
from fp.callables import MutableThunk
from fp.data import Capture, Result, attempt_once
@fieldwise_init
struct View[o: ImmOrigin](MutableThunk):
    comptime Out = Int
    comptime Error = Pointer[String, Self.o]
    var pointer: Self.Error
    def call_mut(mut self) raises Self.Error -> Int: raise self.pointer
def wrong[o: ImmOrigin](ref[o] owner: String) -> Result[Int, Pointer[String, o]]:
    var local = String("local")
    return Capture[String]().run(View(Pointer(to=local)))
def main(): pass
