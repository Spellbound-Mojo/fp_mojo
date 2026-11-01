# error: constraint failed
from fp.iteration import iterated
from fp.algebra import OptionalFamily
@fieldwise_init
struct TWHintFailure(Movable):
    var code: Int
def project(value: Int) raises TWHintFailure -> Optional[Int]: raise TWHintFailure(value)
def main() raises:
    # Explicit evidence must not erase or convert a different native error.
    _ = iterated(range(3)).traverse_void[OptionalFamily, X=Int](project)
