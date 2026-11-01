"""Share state between fibers through Ref, Deferred, Queue and Semaphore."""
from fp.callables import OnceUnary
from fp.effects import Outcome
from fp.effects.async_runtime import IO, Deferred, Queue, Ref, Semaphore, run


def value[T: Movable & Deinitable](var outcome: Outcome[T, Int]) -> T:
    return outcome.take()._take_ok()


def increment(var count: Int) -> Int:
    return count + 1


def add_pair(var pair: Tuple[Int, Int]) -> Int:
    return pair[0] + pair[1]


@fieldwise_init
struct ReadRef(OnceUnary):
    var cell: Ref[Int]
    comptime Arg = Tuple[NoneType, NoneType]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var done: Tuple[NoneType, NoneType]) -> IO[Int, Int]:
        return self.cell.get[Int]()


def counted() -> IO[Int, Int]:
    # Two fibers update one Ref; each update runs once, atomically.
    var cell = Ref(0)
    var twice = cell.update[Int](increment).both(cell.update[Int](increment))
    return twice^.flat_map(ReadRef(cell^))


@fieldwise_init
struct Publish(OnceUnary):
    var answer: Deferred[Int]
    comptime Arg = NoneType
    comptime Out = IO[Bool, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Bool, Int]:
        return self.answer.complete[Int](42)


def awaited() -> IO[Int, Int]:
    # Both readers wait for the one completion and receive a copy each.
    var answer = Deferred[Int]()
    var readers = answer.get[Int]().both(answer.get[Int]())
    var writer = IO[NoneType, Int].cede().flat_map(Publish(answer^))
    return readers^.map(add_pair).both(writer^).map(first_of)


def first_of(var pair: Tuple[Int, Bool]) -> Int:
    return pair[0]


@fieldwise_init
struct Offer(OnceUnary):
    """Offer the values in order, one after another."""
    var queue: Queue[Int]
    var next: Int
    var last: Int
    comptime Arg = NoneType
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[NoneType, Int]:
        if self.next > self.last:
            return IO[NoneType, Int].pure(None)
        var offered = self.queue.offer[Int](self.next)
        return offered^.flat_map(Offer(self.queue^, self.next + 1, self.last))


@fieldwise_init
struct Collect(OnceUnary):
    """Take `left` more values and append them in the order they leave the queue."""
    var queue: Queue[Int]
    var left: Int
    comptime Arg = List[Int]
    comptime Out = IO[List[Int], Int]

    def call_once(deinit self, var taken: List[Int]) -> IO[List[Int], Int]:
        if self.left == 0:
            return IO[List[Int], Int].pure(taken^)
        return self.queue.take[Int]().map(Append(taken^)).flat_map(Collect(self.queue^, self.left - 1))


@fieldwise_init
struct Append(OnceUnary):
    var values: List[Int]
    comptime Arg = Int
    comptime Out = List[Int]

    def call_once(deinit self, var value: Int) -> List[Int]:
        self.values.append(value)
        return self.values^


def keep_values(var pair: Tuple[List[Int], NoneType]) -> List[Int]:
    return pair[0].copy()


def queued() raises -> IO[List[Int], Int]:
    # A bounded queue of two: the producer waits for room, the consumer for values.
    var queue = Queue[Int](2)
    var consumer = IO[List[Int], Int].pure(List[Int]()).flat_map(Collect(queue.copy(), 4))
    var producer = IO[NoneType, Int].pure(None).flat_map(Offer(queue^, 1, 4))
    return consumer^.both(producer^).map(keep_values)


def main() raises:
    print("counter:", value(run(counted())))
    print("deferred readers:", value(run(awaited())))
    var values = value(run(queued()))
    print("queue:", values[0], values[1], values[2], values[3])
    var permits = Semaphore(1)
    print("with permit:", value(run(permits.with_permit(IO[Int, Int].pure(7)))))
    print("permits after:", value(run(permits.available[Int]())))
