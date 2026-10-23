# error: use of uninitialized value
from fp.iteration import iterated
from fp.algebra import OptionalFamily
@fieldwise_init
struct EFUsedAcc(Movable):
    var value: String
def step(var a: EFUsedAcc,b: Int) -> Optional[EFUsedAcc]: return Optional(a^)
def main():
    var acc = EFUsedAcc("start")
    _ = iterated(range(2)).fold_effect[OptionalFamily](step,acc^)
    print(acc.value)
