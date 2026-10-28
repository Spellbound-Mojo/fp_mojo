# error: uninitialized
from fp.functions import pipeline, kleisli
from fp.algebra import OptionalFamily
from fp.effects import Reader, run

@fieldwise_init
struct Capture(Movable):
    var value: Int

def main():
    var capture = Capture(1)
    def step(value: Int) {var capture^} -> Optional[Int]: return Optional(value + capture.value)
    var chain = kleisli[OptionalFamily](step^)
    var pending = pipeline[Reader[Int]](Reader[Int].pure(3)).map(chain).get()
    var moved = chain^
    _ = moved^.call_once(4)
    _ = run[Reader[Int]](pending^, 0)
