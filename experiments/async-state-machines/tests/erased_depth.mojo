"""A million-link chain of one stable type, built and torn down iteratively."""
from std.memory import ArcPointer, OwnedPointer
from fp._internal.erased import _Erased
from foundation import check

comptime DEPTH = 1_000_000


@fieldwise_init
struct Count(Movable):
    var log: ArcPointer[List[Int]]

    def __deinit__(deinit self):
        self.log[][0] += 1


@fieldwise_init
struct Label(Movable):
    var text: String
    var log: ArcPointer[List[Int]]

    def __deinit__(deinit self):
        self.log[][1] += 1


struct Link(Movable):
    """Recurses only through native owned indirection; payload types vary at runtime."""
    var value: Int
    var payload: _Erased
    var next: Optional[OwnedPointer[Link]]

    def __init__(out self, value: Int, var payload: _Erased, var next: Optional[OwnedPointer[Link]]):
        self.value = value
        self.payload = payload^
        self.next = next^

    def __deinit__(deinit self):
        # Detach descendants before each node drops, so destruction never recurses.
        var next = self.next^
        while next:
            var node = next.take()
            next = node[].detach()

    def detach(mut self) -> Optional[OwnedPointer[Link]]:
        if not self.next:
            return None
        return Optional(self.next.take())


def build(depth: Int, log: ArcPointer[List[Int]]) -> Link:
    # One stable type for every depth: no type is instantiated per iteration.
    var head: Optional[OwnedPointer[Link]] = None
    for i in range(depth - 1, 0, -1):
        var payload = _Erased(Count(log.copy())) if i % 2 == 0 else _Erased(Label(String("link"), log.copy()))
        head = Optional(OwnedPointer(Link(i, payload^, head^)))
    return Link(0, _Erased(Count(log.copy())), head^)


def consume_iteratively():
    var log = ArcPointer(List[Int]([0, 0]))
    var head = Optional(OwnedPointer(build(DEPTH, log)))
    var visited = 0
    var total = 0
    while head:
        var node = head.take()
        check(node[].value == visited, "links consumed in construction order")
        total += node[].value
        visited += 1
        head = node[].detach()
    check(visited == DEPTH and total == DEPTH * (DEPTH - 1) // 2, "every link visited once")
    check(log[][0] + log[][1] == DEPTH and log[][1] == DEPTH // 2, "every heterogeneous payload destroyed once")


def drop_unopened():
    var log = ArcPointer(List[Int]([0, 0]))
    var chain = build(DEPTH, log)
    check(log[][0] + log[][1] == 0, "construction destroys nothing")
    _ = chain^
    check(log[][0] + log[][1] == DEPTH, "deep chain destroyed iteratively and exactly once")


def drop_through_erasure():
    # The erased owner's destroy function runs Link's iterative destructor.
    var log = ArcPointer(List[Int]([0, 0]))
    var erased = _Erased(build(DEPTH, log))
    _ = erased^
    check(log[][0] + log[][1] == DEPTH, "erased deep chain destroyed exactly once")


def main():
    consume_iteratively()
    drop_unopened()
    drop_through_erasure()
    print("erased depth: one stable recursive type, a million runtime links, iterative consumption and teardown")
