"""Share mutable state between fibers safely on either profile."""
from std.atomic import Atomic
from std.memory import ArcPointer
from fp.algebra import par_traverse
from fp.callables import OnceUnary, Unary
from fp.effects import ThreadTransferable, assert_thread_transferable, Outcome
from fp.effects.async_runtime import IO, Ref, run


def value[T: Movable & Deinitable](var outcome: Outcome[T, Int]) -> T:
    """The program's success value; a failure or cancellation aborts."""
    var success = outcome.take().to_optional()
    return success.take()


struct Counter(Copyable, ThreadTransferable):
    """Every access to the shared target is atomic, so the claim holds."""
    var count: ArcPointer[Atomic[Int]]

    def __init__(out self):
        self.count = ArcPointer(Atomic[Int](0))


@fieldwise_init
struct Bump(Unary, Copyable):
    """Each element's fiber bumps the shared counter; fibers may run on different workers."""
    var counter: Counter
    comptime Arg = Int
    comptime Out = IO[NoneType, Int]
    comptime Error = Never

    def call(self, var index: Int) -> IO[NoneType, Int]:
        return IO[NoneType, Int].pure(None).map(Increment(self.counter.copy()))


@fieldwise_init
struct Increment(OnceUnary):
    var counter: Counter
    comptime Arg = NoneType
    comptime Out = NoneType

    def call_once(deinit self, var unit: NoneType) -> NoneType:
        _ = self.counter.count[].fetch_add(1)
        return None


def add_one(var count: Int) -> Int:
    return count + 1


@fieldwise_init
struct BumpRef(Unary, Copyable):
    """The same through a Ref, whose updates are atomic with respect to other fibers."""
    var cell: Ref[Int]
    comptime Arg = Int
    comptime Out = IO[NoneType, Int]
    comptime Error = Never

    def call(self, var index: Int) -> IO[NoneType, Int]:
        return self.cell.update[Int](add_one)


def indices() -> List[Int]:
    var values = List[Int](capacity=1000)
    for i in range(1000):
        values.append(i)
    return values^


def main() raises:
    # The opt-in check is stricter than erasure's: it also rejects ArcPointer
    # outside a ThreadTransferable struct. Counter conforms, so it passes.
    assert_thread_transferable[Counter]()

    var counter = Counter()
    _ = run(par_traverse(indices(), Bump(counter.copy())))
    print("atomic counter:", counter.count[].load())

    var cell = Ref(0)
    _ = run(par_traverse(indices(), BumpRef(cell.copy())))
    print("ref counter:", value(run(cell.get[Int]())))
