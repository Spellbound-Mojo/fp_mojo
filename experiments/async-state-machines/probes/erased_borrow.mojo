"""Compile-only: Mojo 1.2 accepts erasing a machine that borrows a local.

The borrowed origin appears in neither the value nor the error type, so the
carrier drops it and nothing keeps the owner alive. This documents the
owned-state precondition the compiler cannot check. Never execute this program.
"""
from fp.data import Result, Ok
from fp.effects import IOContext, EffectFailure
from fp.effects._async.kernel import Machine, Step, run
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
    # Accepted without diagnostics: the returned carrier outlives `owner`.
    return _ErasedMachine[Int, Int](Reads(Pointer(to=owner)))


def main():
    var outcome = run(escape())
    _ = outcome^
