"""Demand-driven branching, bounded atomic admission, and owner cleanup."""
from fp.iteration import iterated, partition, partition_map, unzip, Unbounded, BoundedFail, BufferCapacityError, BufferLimitExceeded
from fp.data import Result, Ok, Err
from fp.callables import MutableUnary
from fp.callables.products import _take_pair
from std.iter import Iterator, IterableOwned, next
from std.memory import ArcPointer, MaybeUninit
from std.testing import assert_equal
from std.os import abort


def i3_even(value: Int) -> Bool: return value % 2 == 0

def i3_classify(var value: Int) -> Result[Int, String]:
    if i3_even(value): return Ok(value)
    return Err(String(value))


def i3_capacity(n: Int) -> BoundedFail:
    try: return BoundedFail(n)
    except BufferCapacityError: abort("test requires positive capacity")


def i3_done[I: Iterator](mut value: I) raises where conforms_to(I.Element, Deinitable):
    for _ in range(2):
        var stopped = False
        try: _ = next(value)
        except StopIteration: stopped = True
        assert_equal(stopped, True)


@fieldwise_init
struct I3Source(Iterator, IterableOwned):
    comptime Element = Int
    comptime IteratorOwnedType = Self
    var position: Int
    var end: Int
    var pulls: ArcPointer[List[Int]]
    var drops: ArcPointer[Int]
    def __iter__(var self) -> Self:
        self.position = 0
        return self^
    def __next__(mut self) raises StopIteration -> Int:
        var value = self.position
        self.position += 1
        self.pulls[].append(value)
        # Deliberately resumes after exhaustion if polled again.
        if value == self.end: raise StopIteration()
        return value
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct I3Classifier(MutableUnary):
    comptime Arg = Int
    comptime Out = Result[Int, String]
    var calls: ArcPointer[Int]
    var drops: ArcPointer[Int]
    def call_mut(mut self, var value: Int) -> Self.Out:
        self.calls[] += 1
        return i3_classify(value)
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct I3Token(Movable):
    var id: Int
    var drops: ArcPointer[List[Int]]
    def __deinit__(deinit self): self.drops[].append(self.id)


def i3_token_even(value: I3Token) -> Bool: return value.id % 2 == 0


def demand() raises:
    var pulls = ArcPointer(List[Int]())
    var drops = ArcPointer(0)
    var calls = 0
    def predicate(value: Int) {mut calls} -> Bool:
        calls += 1
        return i3_even(value)
    var branches = iterated(I3Source(1, 6, pulls, drops)).partition(predicate, buffer=Unbounded())
    assert_equal(len(pulls[]), 0)
    assert_equal(calls, 0)
    assert_equal(next(branches[1]), 1)
    assert_equal(next(branches[1]), 3)
    assert_equal(next(branches[0]), 2)
    assert_equal(next(branches[1]), 5)
    assert_equal(next(branches[0]), 4)
    i3_done(branches[0])
    i3_done(branches[1])
    assert_equal(pulls[], [1,2,3,4,5,6])
    assert_equal(calls, 5)
    assert_equal(drops[], 1)
    branches[0].close()
    branches[0].close()
    var empty = partition(range(0), i3_even, buffer=Unbounded())
    i3_done(empty[1])
    i3_done(empty[0])


def failures() raises:
    for invalid in range(-1,1):
        var rejected = False
        try: _ = BoundedFail(invalid)
        except error:
            rejected = True
            assert_equal(error.capacity, invalid)
        assert_equal(rejected, True)
    var pulls = ArcPointer(List[Int]())
    var drops = ArcPointer(0)
    var branches = partition(I3Source(0,5,pulls,drops), i3_even, buffer=i3_capacity(1))
    assert_equal(next(branches[0])._take_ok(), 0)
    assert_equal(next(branches[0])._take_ok(), 2)
    var first_error = next(branches[0])._take_err()
    var second_error = next(branches[1])._take_err()
    assert_equal(first_error.branch, 1)
    assert_equal(first_error.capacity, 1)
    assert_equal(second_error.branch, first_error.branch)
    assert_equal(second_error.capacity, first_error.capacity)
    i3_done(branches[0])
    i3_done(branches[1])
    assert_equal(pulls[], [0,1,2,3])
    assert_equal(drops[], 1)
    # Reversed demand reports the first queue instead.
    var reverse = partition(range(8), i3_even, buffer=i3_capacity(1))
    assert_equal(next(reverse[1])._take_ok(), 1)
    assert_equal(next(reverse[1])._take_err().branch, 0)
    assert_equal(next(reverse[0])._take_err().branch, 0)
    # Closing a branch removes its budget, without prefetching.
    var closed = partition(range(6), i3_even, buffer=i3_capacity(1))
    closed[1].close()
    for expected in range(0,6,2):
        assert_equal(next(closed[0])._take_ok(), expected)
    i3_done(closed[0])
    i3_done(closed[1])


def classify_and_close() raises:
    var calls = ArcPointer(0)
    var drops = ArcPointer(0)
    var pulls = ArcPointer(List[Int]())
    var source_drops = ArcPointer(0)
    var branches = iterated(I3Source(0,6,pulls,source_drops)).partition_map(I3Classifier(calls,drops), buffer=Unbounded())
    assert_equal(calls[], 0)
    assert_equal(next(branches[1]), "1")
    assert_equal(next(branches[1]), "3")
    assert_equal(next(branches[0]), 0)
    branches[0].close()  # Releases queued 2; future even values are discarded.
    assert_equal(next(branches[1]), "5")
    branches[1].close()
    assert_equal(calls[], 6)
    assert_equal(drops[], 1)
    assert_equal(source_drops[], 1)
    assert_equal(pulls[], [0,1,2,3,4,5])
    var offset = 10
    def native(var value: Int) {offset} -> Result[Int, String]:
        if i3_even(value): return Ok(value + offset)
        return Err(String(value))
    var captured = iterated(range(3)).partition_map(native, buffer=Unbounded())
    assert_equal(next(captured[1]), "1")
    assert_equal(next(captured[0]), 10)
    assert_equal(next(captured[0]), 12)
    var thin = partition_map(range(3), i3_classify, buffer=Unbounded())
    assert_equal(next(thin[0]), 0)
    assert_equal(next(thin[1]), "1")


def i3_move_classify(var value: I3Token) -> Result[I3Token,I3Token]:
    if value.id % 2 == 0: return Ok(value^)
    return Err(value^)


def owned() raises:
    var drops = ArcPointer(List[Int]())
    var values = List[I3Token]()
    for id in range(4): values.append(I3Token(id, drops))
    var branches = partition(values^, i3_token_even, buffer=Unbounded())
    var value = next(branches[1])
    assert_equal(value.id, 1)
    _ = value^
    branches[0].close()  # queued zero dies immediately
    assert_equal(drops[], [1,0])
    branches[1].close()  # unpulled tail dies without classification
    assert_equal(len(drops[]), 4)
    drops[].clear()
    var classified_values = List[I3Token]()
    classified_values.append(I3Token(6,drops))
    classified_values.append(I3Token(7,drops))
    var classified = partition_map(classified_values^, i3_move_classify, buffer=Unbounded())
    var rejected = next(classified[1])
    assert_equal(rejected.id, 7)
    _ = rejected^
    var accepted = next(classified[0])
    assert_equal(accepted.id, 6)
    _ = accepted^
    assert_equal(drops[], [7,6])
    # Independently move the native tuple's fields, then drop one handle.
    var pulls = ArcPointer(List[Int]())
    var source_drops = ArcPointer(0)
    var handles = partition(I3Source(0,5,pulls,source_drops), i3_even, buffer=i3_capacity(1))
    var first = MaybeUninit[type_of(handles[0])]()
    var second = MaybeUninit[type_of(handles[1])]()
    _take_pair(handles^, first, second)
    var a = first^.unsafe_assume_init()
    _ = second^.unsafe_assume_init()
    assert_equal(next(a)._take_ok(), 0)
    assert_equal(next(a)._take_ok(), 2)
    assert_equal(next(a)._take_ok(), 4)
    _ = a^
    assert_equal(source_drops[], 1)
    assert_equal(pulls[], [0,1,2,3,4])
    # Unzip must reject both fields of the overflowing pair.
    drops[].clear()
    var pairs = List[Tuple[I3Token,I3Token]]()
    pairs.append((I3Token(10,drops),I3Token(11,drops)))
    pairs.append((I3Token(20,drops),I3Token(21,drops)))
    pairs.append((I3Token(30,drops),I3Token(31,drops)))
    var split = iterated(pairs^).unzip(buffer=i3_capacity(1))
    var yielded = next(split[0])._take_ok()
    assert_equal(yielded.id, 10)
    assert_equal(next(split[0])._take_err().branch, 1)
    assert_equal(next(split[1])._take_err().branch, 1)
    assert_equal(len(drops[]), 5)
    _ = yielded^
    assert_equal(len(drops[]), 6)
    i3_done(split[0])
    i3_done(split[1])
    var simple: List[Tuple[Int,String]] = [(1,"a"),(2,"b")]
    var unzipped = unzip(simple^, buffer=Unbounded())
    assert_equal(next(unzipped[1]), "a")
    assert_equal(next(unzipped[1]), "b")
    i3_done(unzipped[1])
    assert_equal(next(unzipped[0]), 1)
    assert_equal(next(unzipped[0]), 2)
    i3_done(unzipped[0])


def main() raises:
    demand()
    failures()
    classify_and_close()
    owned()
    generic_and_guard()

from fp.callables import BorrowCallable
from fp.iteration import PartitionMapBranches
from fp.data._result import _ResultType
from fp._internal.exclusive import _ExclusiveCell, _exclusive

@fieldwise_init
struct I3Predicate(BorrowCallable):
    comptime Payload = Int
    comptime Result = Bool
    var threshold: Int
    def invoke(self, ref payload: Self.Payload) raises Never capturing -> Self.Result: return payload >= self.threshold


def i3_generic[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, //,
               F: def(var T) -> U](var function: F, var source: I) -> PartitionMapBranches[T,U,I,F,Unbounded] where I.Element == T and conforms_to(U, _ResultType):
    return partition_map[T=T,U=U](source^, function^, buffer=Unbounded())


def generic_and_guard() raises:
    var values: List[Int] = [1,2,3]
    from std.iter import iter
    var branches = iterated(iter(values)).partition(I3Predicate(2), buffer=Unbounded())
    assert_equal(next(branches[0]), 2)
    assert_equal(next(branches[1]), 1)
    var base = 10
    def function(var value: Int) {imm base} -> Result[Int,Int]:
        if value == 0: return Ok(base)
        return Err(value)
    var classified = i3_generic(function, iter(range(2)))
    assert_equal(next(classified[0]), 10)
    assert_equal(next(classified[1]), 1)
    var pointers = List[Pointer[Int,origin_of(base)]]()
    pointers.append(Pointer(to=base))
    var addresses = partition_map(pointers^, i3_pointer[origin_of(base)], buffer=Unbounded())
    assert_equal(next(addresses[0])[], 10)
    var owner = ArcPointer(_ExclusiveCell(Int32(0), 1))
    var lease = _exclusive(owner)
    var borrowed = Pointer(to=lease.value())
    _ = lease^
    # Native lifetime extension keeps the lease locked through its last borrow.
    assert_equal(owner[].gate, 1)
    borrowed[] = 2
    assert_equal(borrowed[], 2)
    assert_equal(owner[].gate, 0)
    var again = _exclusive(owner)
    assert_equal(again.value(), 2)


def i3_pointer[o: MutOrigin](var value: Pointer[Int,o]) -> Result[Pointer[Int,o],Int]:
    return Ok(value)
