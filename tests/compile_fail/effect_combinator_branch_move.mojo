# error: no matching method in call to 'fold_effect'
from fp.iteration import iterated
from fp.algebra import ListFamily
@fieldwise_init
struct EFMoveInput(Movable):
    var text: String
def step(a: Int,var x: EFMoveInput) -> List[Int]: return [a+1]
def main():
    var xs = List[EFMoveInput]()
    xs.append(EFMoveInput("one"))
    _ = iterated(xs^).fold_effect[ListFamily](step,0)
