# error: value passed to 'function' cannot be converted
from fp.iteration import iterated
from fp.callables import BorrowSignature
@fieldwise_init
struct Owner(Movable):
    var value: Int
def consume(var value: Owner) -> Optional[Int]: return Optional(value.value)
def main():
    var values = List[Owner]()
    values.append(Owner(1))
    _ = iterated(values^).traverse_tap(BorrowSignature[Owner,Optional[Int]].capture(consume))
