# error: uninitialized
from fp.functions import pipeline, kleisli
from fp.algebra import IdentityFamily
from fp.effects import Reader, ResultT, run

@fieldwise_init
struct Capture(Movable):
    var text: String

def main():
    comptime Layer = ResultT[Reader[Int], String]
    var capture = Capture("fallback")
    def restore(var reason: String) {var capture^} -> Int: return capture.text.byte_length()
    var handler = kleisli[IdentityFamily](restore^)
    var pending = pipeline[Layer](Layer.fail[Int](String("bad"))).recover(handler).get()
    var moved = handler^
    _ = moved^.call_once(String("other"))
    _ = run[Reader[Int]](pending^, 0)
