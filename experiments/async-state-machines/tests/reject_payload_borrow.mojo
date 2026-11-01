# error: constraint failed: cannot erase `reject_payload_borrow.Reads[{}, {}]`: it reaches a `Pointer` field of `reject_payload_borrow.Reads[{}, {}]`, which is not ThreadTransferable
"""Must be rejected: erasing a machine that borrows a local, whose origin the carrier drops."""
from fp.data import Result, Ok
from fp.effects import IOContext, EffectFailure
from fp.effects._async.kernel import Machine, Step
from fp.effects._async.erased import _ErasedMachine


@fieldwise_init
struct Reads[o: ImmOrigin](Machine):
    var owner: Pointer[List[Int], Self.o]
    comptime Value = Int
    comptime Error = Int

    def poll(mut self, context: IOContext[Int]) -> Step[Int, Int]:
        return Step[Int, Int].ready(Optional(Result[Int, EffectFailure[Int]](Ok(len(self.owner[])))))


def escape() -> _ErasedMachine[Int, Int]:
    var owner = List[Int]([1, 2, 3])
    return _ErasedMachine[Int, Int](Reads(Pointer(to=owner)))


def main():
    _ = escape()
