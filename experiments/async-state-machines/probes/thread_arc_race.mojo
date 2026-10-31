"""Runs: an `ArcPointer` to unsynchronized data shared by two OS threads.

Each thread holds its own copy of the `ArcPointer` (the reference count is
atomic) and increments the shared `Int` without synchronization. This is the
data race the payload contract forbids: build at O0 (a higher level may fold
the loop) and the total falls short of 200,000. With `atomic` as the first
argument the counter is an `Atomic` and the total is exact. A
`--sanitize thread` build aborts at startup in the cloud container
(`mmap at bad address`); see async-thread-safety.md.
"""
from std.ffi import external_call
from std.atomic import Atomic
from std.memory import ArcPointer
from std.sys import argv

comptime _ROUNDS = 100000


@fieldwise_init
struct Work(Movable):
    var plain: ArcPointer[Int]
    var atomic: ArcPointer[Atomic[Int64]]
    var use_atomic: Bool


def _worker[o: MutOrigin](work: Pointer[Work, o]) abi("C") -> OptionalPointer[NoneType, MutUntrackedOrigin]:
    for _ in range(_ROUNDS):
        if work[].use_atomic:
            _ = work[].atomic[].fetch_add(1)
        else:
            work[].plain[] += 1
    return None


def main():
    var use_atomic = len(argv()) > 1 and argv()[1] == "atomic"
    var plain = ArcPointer(0)
    var atomic = ArcPointer(Atomic[Int64](0))
    var first = Work(plain.copy(), atomic.copy(), use_atomic)
    var second = Work(plain.copy(), atomic.copy(), use_atomic)
    var first_handle = UInt64(0)
    var second_handle = UInt64(0)
    _ = external_call["pthread_create", Int32](Pointer(to=first_handle), OptionalPointer[NoneType, ImmUntrackedOrigin](), _worker[origin_of(first)], Pointer(to=first))
    _ = external_call["pthread_create", Int32](Pointer(to=second_handle), OptionalPointer[NoneType, ImmUntrackedOrigin](), _worker[origin_of(second)], Pointer(to=second))
    _ = external_call["pthread_join", Int32](first_handle, OptionalPointer[NoneType, MutUntrackedOrigin]())
    _ = external_call["pthread_join", Int32](second_handle, OptionalPointer[NoneType, MutUntrackedOrigin]())
    _ = first^
    _ = second^
    if use_atomic:
        print("atomic total", atomic[].load(), "of", 2 * _ROUNDS)
    else:
        print("plain total", plain[], "of", 2 * _ROUNDS)
