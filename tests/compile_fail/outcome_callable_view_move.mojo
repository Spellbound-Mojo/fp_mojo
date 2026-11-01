# error: uninitialized
from fp.functions import pipeline, kleisli
from fp.algebra import IdentityFamily
from fp.effects import Reader, ResultT, run

@fieldwise_init
struct Capture(Movable):
    var value: Int

def success(value: Int) -> Int: return value

def main():
    var capture = Capture(1)
    def failure(var reason: String) {var capture^} -> Int: return capture.value
    var on_err = kleisli[IdentityFamily](failure^)
    comptime Later = ResultT[Reader[Int], String]
    var pending = pipeline[Later](Later.fail[Int](String("bad"))).redeem(success, on_err).get()
    var moved = on_err^
    _ = moved^.call_once(String("other"))
    _ = run[Reader[Int]](pending^, 0)
