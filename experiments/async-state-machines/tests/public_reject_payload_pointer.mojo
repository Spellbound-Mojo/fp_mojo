# error: constraint failed: cannot erase `public_reject_payload_pointer.Raw`: it reaches a `Pointer` field of `public_reject_payload_pointer.Raw`, which is not ThreadTransferable
from fp.effects.async_runtime import IO


struct Raw(Movable):
    var address: Pointer[Int, MutUntrackedOrigin]

    def __init__(out self, value: Int):
        self.address = Pointer[Int, MutUntrackedOrigin](unsafe_from_address=value)


def main():
    # An IO may move its payload to another thread; an unmarked raw pointer is rejected.
    _ = IO[Raw, Int].pure(Raw(8))
