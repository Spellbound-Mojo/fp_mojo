# error: uninitialized
from fp.functions import kleisli
from fp.iteration import iterated
from fp.effects import Reader, run
@fieldwise_init
struct Capture(Movable):
    var text: String
def source(x: Int) -> Reader[Int].Pure[Int]: return Reader[Int].pure(x)
def main():
    var capture = Capture("data")
    def next_step(x: Int) {var capture^} -> Reader[Int].Pure[Int]:
        return Reader[Int].pure(x + capture.text.byte_length())
    var chain = kleisli[Reader[Int]](source).then(next_step^)
    var values: List[Int] = [1]
    var mapped = iterated(values^).map(chain).collect_list()
    var moved = chain^
    _ = moved^.call_once(2)
    var action = mapped.pop()
    _ = run[Reader[Int]](action^, 0)
