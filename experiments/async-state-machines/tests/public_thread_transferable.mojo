"""Erasure admits owned payloads and marked types; the library's owners are thread-transferable."""
from std.os import abort
from std.atomic import Atomic
from std.memory import ArcPointer
from std.memory.alloc import unsafe_alloc
from fp.effects import Outcome, EffectFailure, fold_outcome, CancellationToken, ThreadTransferable, assert_thread_transferable
from fp.effects import Ref as SyncRef, Deferred as SyncDeferred, Queue as SyncQueue, Semaphore as SyncSemaphore, Permit
from fp.effects.async_runtime import IO, run, Fiber, Ref, Deferred, Queue, Semaphore, Supervisor, Clock, Completion, BlockingPool, IORuntimeConfig


struct Cell(Movable, ThreadTransferable):
    """Owns one heap Int through a raw pointer and never shares it."""

    # ThreadTransferable: the allocation is owned uniquely and freed exactly
    # once, by whichever thread destroys the cell.
    var address: Pointer[Int, MutUntrackedOrigin]

    def __init__(out self, value: Int):
        self.address = unsafe_alloc[Int](1)
        self.address.unsafe_write(value)

    def value(self) -> Int:
        # Read through a method so the read is a use of the cell itself.
        return self.address[]

    def __deinit__(deinit self):
        self.address.unsafe_deinit_pointee()
        self.address.unsafe_free()


@fieldwise_init
struct Holder(Movable):
    """An unmarked struct is admitted when it reaches only a marked one."""
    var name: String
    var cell: Cell


struct Counter(Movable, ThreadTransferable):
    # ThreadTransferable: every access to the shared target is atomic.
    var count: ArcPointer[Atomic[Int64]]

    def __init__(out self):
        self.count = ArcPointer(Atomic[Int64](0))


@fieldwise_init
struct Shared(Movable):
    """Shared ownership is not rejected by erasure, only by the assertion."""
    var data: ArcPointer[List[Int]]


def main():
    var cell = take(run(IO[Holder, Int].pure(Holder(String("cell"), Cell(41)))))
    check(cell.cell.value() == 41 and cell.name == "cell", "a marked raw-pointer owner is erased and returned")
    var plain = run(IO[List[String], Int].pure([String("a"), String("b")]))
    check(len(take(plain^)) == 2, "standard containers of owned data are erased")
    var maybe = run(IO[Optional[String], Int].pure(Optional(String("x"))))
    check(take(maybe^).value() == "x", "Optional of owned data is erased")
    var shared = run(IO[Shared, Int].pure(Shared(ArcPointer(List[Int]([1, 2, 3])))))
    check(len(take(shared^).data[]) == 3, "ArcPointer is not rejected by default")
    assert_thread_transferable[Int]()
    assert_thread_transferable[String]()
    assert_thread_transferable[List[String]]()
    assert_thread_transferable[Optional[Int]]()
    assert_thread_transferable[Holder]()
    assert_thread_transferable[Counter]()
    assert_thread_transferable[IO[Int, Int]]()
    assert_thread_transferable[Ref[Int]]()
    assert_thread_transferable[Deferred[Int]]()
    assert_thread_transferable[Queue[Int]]()
    assert_thread_transferable[Semaphore]()
    assert_thread_transferable[Fiber[Int, Int]]()
    assert_thread_transferable[Supervisor[Int]]()
    assert_thread_transferable[Completion[Int, Int]]()
    assert_thread_transferable[Clock]()
    assert_thread_transferable[BlockingPool]()
    assert_thread_transferable[IORuntimeConfig]()
    assert_thread_transferable[CancellationToken]()
    assert_thread_transferable[SyncRef[Int]]()
    assert_thread_transferable[SyncDeferred[Int]]()
    assert_thread_transferable[SyncQueue[Int]]()
    assert_thread_transferable[SyncSemaphore]()
    assert_thread_transferable[Permit]()
    print("thread transferable: marked owners erased, standard payloads, shared ownership by default, library owners")


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def take[T: Movable & Deinitable](var outcome: Outcome[T, Int]) -> T:
    def keep(var value: T) -> T:
        return value^
    def failure(var value: EffectFailure[Int]) -> T:
        abort("unexpected failure")
    def canceled() -> T:
        abort("unexpected cancellation")
    return fold_outcome(outcome^, keep, failure, canceled)
