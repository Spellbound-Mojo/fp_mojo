"""Retain effectful projections without private types in generic signatures."""
from fp.algebra import Monad, FlatPairWithContract, ListFamily
from fp.callables import BorrowCallContract, BorrowCallable
from fp.effects import Reader, run
from fp.functions import Pipeline, pipeline


# This return type previously needed I.Bound[V, _EffectRetain[
# I.Element[V], I, C, False, True]] and the matching I.BindError projection.
# The public contract names that operation without importing its continuation.
def paired[I: Monad, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](
    var value: V, var projection: C
) raises FlatPairWithContract[I,V,C].Error -> Pipeline[FlatPairWithContract[I,V,C].Family, FlatPairWithContract[I,V,C].Out] where FlatPairWithContract[I,V,C].Compatible:
    return pipeline[I](value^).flat_pair_with(projection^)


@fieldwise_init
struct AddTen[I: Monad](BorrowCallable):
    comptime Payload = Int
    comptime Result = Self.I.Pure[Int]
    def invoke(self, ref value: Int) -> Self.Result:
        return Self.I.pure(value + 10)


def main() raises:
    var immediate = paired[ListFamily](List[Int]([2]), AddTen[ListFamily]()).get()
    print("paired:", immediate[0][0], immediate[0][1])

    comptime Environment = Reader[Int]
    var pending = paired[Environment](Environment.pure(3), AddTen[Environment]()).get()
    var delayed = run[Environment](pending^, 0)
    print("deferred:", delayed[0], delayed[1])
