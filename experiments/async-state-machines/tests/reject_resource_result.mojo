# error: cannot be converted from 'Span[Int, p]' to 'Span[Int, o]'
from state_machine import ScopedMachine, Step
from fp.effects import IOContext, CancellationToken
from foundation import success


@fieldwise_init
struct Escape[o: ImmOrigin](ScopedMachine):
    comptime Input = List[Int]
    comptime Value = Span[Int, Self.o]
    comptime Error = Int

    def poll[p: ImmOrigin](mut self, ref[p] value: Self.Input, context: IOContext[Int]) -> Step[Self.Value, Int]:
        return success[Self.Value, Int](Span(value))


def main():
    var use = Escape[ImmUntrackedOrigin]()
    var owner = List[Int]([1, 2])
    _ = use.poll(owner, IOContext[Int](CancellationToken(), False))
