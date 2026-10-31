"""Family contracts preserve generic calls, exact origins and native errors."""
from fp.algebra import Functor, Applicative, Traversable, ListFamily, ResultFamily, ValidationFamily, ListMonoid, map, map2, map2_lazy, traverse, sequence
from fp.callables import Unary, OnceUnary, OnceBinary, OnceThunk, UnaryContract, BinaryContract, ThunkContract
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from std.testing import assert_equal

@fieldwise_init
struct FamilyContractPass[T: Movable & Deinitable](OnceUnary):
    comptime Arg = Self.T
    comptime Out = Self.T
    def call_once(deinit self, var value: Self.T) -> Self.T: return value^
@fieldwise_init
struct FamilyContractRight[A: Movable & Deinitable, B: Movable & Deinitable](OnceBinary):
    comptime First = Self.A
    comptime Second = Self.B
    comptime Out = Self.B
    def call_once(deinit self, var a: Self.A, var b: Self.B) -> Self.B: return b^
@fieldwise_init
struct FamilyContractHeld[V: Movable & Deinitable](OnceThunk):
    var value: Self.V
    comptime Out = Self.V
    def call_once(deinit self) -> Self.V: return self.value^
@fieldwise_init
struct FamilyContractNext[E: Movable & Deinitable](Unary):
    comptime Arg = Int
    comptime Out = Result[Int, Self.E]
    def call(self, var value: Int) -> Self.Out: return Ok(value + 1)

def forward_map[I: Functor, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var source: V) raises I.MapError[V,F] -> I.Mapped[V,F] where I.Element[V] == F.Arg and I.MapCompatible[V,F]:
    return pipeline[I](source^).map(f^).get()
def forward_pair[I: Applicative, V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var f: F, var left: V, var right: R) raises I.CombineError[V,F,R] -> I.Combined[V,F,R] where I.CombineCompatible[V,F,R]:
    return map2_lazy[I](left^, right^, f^)
def forward_traverse[S: Traversable, G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var source: V) raises S.TraverseError[G,V,F] -> S.Traversed[G,V,F] where S.Element[V] == F.Arg and S.TargetCompatible[G,V,F]:
    return traverse[G, S](source^, f^)
def forward_result[T: Movable & Deinitable, E: Movable & Deinitable, F: OnceUnary](var source: Result[T,E], var f: F) raises F.Error -> Result[F.Out,E] where F.Arg == T:
    return map[ResultFamily[E]](source^, f^)

def check(owner: List[Int]) raises:
    var view = Span(owner)
    comptime View = type_of(view)
    comptime Stored = List[View]
    comptime Sequential = ResultFamily[Stored]
    comptime Accumulating = ValidationFamily[ListMonoid[View]]
    def inc(var x: Int) -> Int: return x + 1
    def next(var x: Int) -> Result[Int,Stored]: return Ok(x + 1)
    def fail(var x: Int) raises View {view} -> Int: raise view

    var first = forward_result(Result[View, Stored](Ok(view)), FamilyContractPass[View]())
    assert_equal(Pointer(to=first._ok().value[0]) == Pointer(to=owner[0]), True)
    var kept = forward_map[Sequential](FamilyContractPass[Int](), Result[Int,Stored](Err(Stored([view]))))
    assert_equal(Pointer(to=kept._err().value[0][0]) == Pointer(to=owner[0]), True)
    var validated = forward_map[Accumulating](FamilyContractPass[Int](), Result[Int,Stored](Err(Stored([view]))))
    assert_equal(Pointer(to=validated._err().value[0][0]) == Pointer(to=owner[0]), True)
    assert_equal(map[Sequential](Result[Int,Stored](Ok(2)), inc)._ok().value, 3)
    assert_equal(pipeline[Sequential](Result[Int,Stored](Ok(3))).map(inc).get()._ok().value, 4)
    assert_equal(pipeline[Accumulating](Result[Int,Stored](Ok(4))).map(inc).get()._ok().value, 5)

    var combined = forward_pair[Sequential](FamilyContractRight[Int,View](), Result[Int,Stored](Ok(2)), FamilyContractHeld(Result[View,Stored](Ok(view))))
    assert_equal(Pointer(to=combined._ok().value[0]) == Pointer(to=owner[0]), True)
    var errors = forward_pair[Accumulating](FamilyContractRight[Int,Int](), Result[Int,Stored](Err(Stored([view]))), FamilyContractHeld(Result[Int,Stored](Err(Stored([view])))))
    assert_equal(len(errors._err().value), 2)
    assert_equal(Pointer(to=errors._err().value[1][0]) == Pointer(to=owner[0]), True)
    var paired = map2[Sequential](FamilyContractRight[Int,View](), Result[Int,Stored](Ok(1)), Result[View,Stored](Ok(view)))
    assert_equal(Pointer(to=paired._ok().value[1]) == Pointer(to=owner[1]), True)
    var fluent = pipeline[Accumulating](Result[Int,Stored](Ok(1))).map2(Result[View,Stored](Ok(view)), FamilyContractRight[Int,View]()).get()
    assert_equal(Pointer(to=fluent._ok().value[1]) == Pointer(to=owner[1]), True)

    var traversed = forward_traverse[ListFamily,Sequential](FamilyContractNext[Stored](), List[Int]([1,2]))
    assert_equal(traversed._ok().value, List[Int]([2,3]))
    var gathered = forward_traverse[ListFamily,Accumulating](FamilyContractNext[Stored](), List[Int]([3,4]))
    assert_equal(gathered._ok().value, List[Int]([4,5]))
    var legacy = pipeline[ListFamily](List[Int]([1,2])).traverse[Sequential](next).get()
    assert_equal(legacy._ok().value, List[Int]([2,3]))
    var selected = pipeline(List[Int]([3,4])).traverse[Accumulating](next).get()
    assert_equal(selected._ok().value, List[Int]([4,5]))
    var inputs = List[Result[Int,Stored]]()
    inputs.append(Ok(7))
    assert_equal(sequence[Sequential, ListFamily](inputs^)._ok().value, List[Int]([7]))
    var inputs2 = List[Result[Int,Stored]]()
    inputs2.append(Ok(8))
    assert_equal(pipeline[ListFamily](inputs2^).sequence[Accumulating]().get()._ok().value, List[Int]([8]))

    # Native errors remain independent of the selected stored error.
    var same_origin = False
    try: _ = pipeline(Result[Int,Stored](Ok(1))).raising[View]().map(fail).get()
    except error: same_origin = Pointer(to=error[0]) == Pointer(to=owner[0])
    assert_equal(same_origin, True)

def main() raises:
    var owner = List[Int]([7,11])
    check(owner)
