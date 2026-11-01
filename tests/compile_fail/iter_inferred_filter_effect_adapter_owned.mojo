# error: value passed to 'function' cannot be converted
from fp.iteration import iterated
from fp.callables import BorrowSignature
@fieldwise_init
struct Owner(Movable):
    var value: Int
def consume(var value: Owner) -> Optional[Bool]: return Optional(value.value > 0)
def main():
    var values = List[Owner]()
    values.append(Owner(1))
    _ = iterated(values^).filter_effect(BorrowSignature[Owner,Optional[Bool]].capture(consume))
