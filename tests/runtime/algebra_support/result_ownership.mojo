"""Small ownership ledger shared by the focused Result consolidation clients."""
from std.memory import ArcPointer


@fieldwise_init
struct Trace(Movable):
    var drops: List[Int]
    var pulls: Int
    var factories: Int
    var calls: Int
    var restarts: Int


def trace() -> ArcPointer[Trace]:
    var drops = List[Int]()
    for _ in range(8):
        drops.append(0)
    return ArcPointer(Trace(drops^,0,0,0,0))


@fieldwise_init
struct Token(Movable):
    var id: Int
    var trace: ArcPointer[Trace]
    def __deinit__(deinit self):
        self.trace[].drops[self.id] += 1
