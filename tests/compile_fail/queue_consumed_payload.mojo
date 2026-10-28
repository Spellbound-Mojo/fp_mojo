# error: uninitialized
from fp.effects import Queue
@fieldwise_init
struct Owner(Movable):
    var value:Int
def main() raises:
    var queue=Queue[Owner](1)
    var owner=Owner(1)
    var pending=queue.offer[Error](owner^)
    _=owner^
    _=pending^
