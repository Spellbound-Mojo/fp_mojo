# error: uninitialized
from fp.functions import pipeline, kleisli
from fp.algebra import OptionalFamily, StringMonoid
from fp.effects import Reader, run

@fieldwise_init
struct Capture(Movable):
    var value: Int

def main():
    var capture = Capture(1)
    def step(value: Int) {var capture^} -> Reader[Int].Pure[String]: return Reader[Int].pure(String(value + capture.value))
    var chain = kleisli[Reader[Int]](step^)
    var pending = pipeline(List[Int]([3])).fold_map_effect[StringMonoid](chain).get()
    var moved = chain^
    _ = moved^.call_once(4)
    _ = run[Reader[Int]](pending^, 0)
