"""Move-only carry, input and output ledgers shared by scan checks."""
from std.memory import ArcPointer


@fieldwise_init
struct I5Carry(Movable):
    var total: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct I5Input(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct I5Output(Movable):
    var text: String
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1
