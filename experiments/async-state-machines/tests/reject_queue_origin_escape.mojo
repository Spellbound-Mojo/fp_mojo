# error: cannot implicitly convert
from state_machine import Queue
from async_coordination import value

def escape[o: ImmOrigin](ref[o] owner: List[Int]) raises -> Span[Int, ImmUntrackedOrigin]:
    var queue = Queue[Span[Int, o]](1)
    _ = value(queue.offer[Int](Span(owner)))
    return value(queue.take[Int]())

def main() raises:
    var owner = List[Int]([13, 17])
    _ = escape(owner)
