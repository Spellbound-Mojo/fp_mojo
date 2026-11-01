# error: constraint failed: `public_reject_transferable_shared.Shared` is not thread-transferable: it reaches an `ArcPointer` field of `public_reject_transferable_shared.Shared`, which is not ThreadTransferable
from std.memory import ArcPointer
from fp.effects import assert_thread_transferable


struct Shared(Movable):
    # Copies on two workers that mutate the list would race.
    var data: ArcPointer[List[Int]]


def main():
    assert_thread_transferable[Shared]()
