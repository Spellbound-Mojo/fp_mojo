from fp.algebra import Monad, IdentityFamily, OptionalFamily, ListFamily, ResultFamily
from fp.algebra.contracts import FoldContract
from fp.callables import BinaryContract, RepeatableBinary
from fp.functions import pipeline, Pipeline
from context_fold_contract_support import Add, SumOwned, Fallible, owned_items
from algebra_support.box import BoxMonad
from std.testing import assert_equal

def forward[I: Monad, V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](
    var function: F, var initial: F.First, var source: V
) raises FoldContract[I, V, F].Error -> Pipeline[I, FoldContract[I, V, F].Out] where FoldContract[I, V, F].Compatible and RepeatableBinary[F]:
    return pipeline[IdentityFamily](source^).fold_effect[I](initial^).run(function^)

def checked[I: Monad, V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](
    var function: F, var initial: F.First, var source: V
) raises FoldContract[I, V, F].Error -> Pipeline[I, FoldContract[I, V, F].Out] where FoldContract[I, V, F].InvocationCompatible:
    return forward[I](function^, initial^, source^)

@fieldwise_init
struct MissingFoldReceiver[I: Monad](BinaryContract, Movable):
    comptime First = Int
    comptime Second = Int
    comptime Out = Self.I.Pure[Int]

from fp.algebra import pure
from fp.callables import Binary, MutableBinary
from fp.effects import Reader, run
from std.memory import ArcPointer
from std.builtin.rebind import rebind_var
from test_context_failure_forwarding_ownership import Owner

@fieldwise_init
struct Step[G: Monad, fail: Bool](MutableBinary):
    var capture: Owner
    var calls: Int
    comptime First = List[Owner]
    comptime Second = Owner
    comptime Out = Self.G.Pure[List[Owner]]
    comptime Error = Owner
    def call_mut(mut self, var first: Self.First, var second: Owner) raises Owner -> Self.Out:
        self.calls += 1
        self.capture.trace[] += "p" + String(self.calls)
        if Self.fail and second.id == 2:
            raise Owner(7, self.capture.trace)
        first.append(second^)
        return pure[Self.G](first^)

def source(trace: ArcPointer[String]) -> List[Owner]:
    var result = List[Owner]()
    for id in range(1, 4):
        result.append(Owner(id, trace))
    return result^

def initial(trace: ArcPointer[String]) -> List[Owner]:
    var result = List[Owner]()
    result.append(Owner(0, trace))
    return result^

def immediate[G: Monad, fail: Bool]() -> String where FoldContract[G, List[Owner], Step[G, fail]].Compatible and FoldContract[G, List[Owner], Step[G, fail]].Error == Owner:
    var trace = ArcPointer(String())
    try:
        var result = checked[G](Step[G, fail](Owner(9, trace), 0), initial(trace), source(trace)).get()
        trace[] += "r"
        _ = result^
    except error:
        comptime assert type_of(error) == Owner
        var raised = rebind_var[Owner](error^)
        trace[] += "e" + String(raised.id)
        _ = raised^
    trace[] += "z"
    return trace[].copy()

def delayed[fail: Bool, execute: Bool]() -> String:
    comptime G = Reader[Int]
    var trace = ArcPointer(String())
    var pending = checked[G](Step[G, fail](Owner(9, trace), 0), initial(trace), source(trace)).get()
    trace[] += "d"
    try:
        if execute:
            var result = run[G](pending^, 0)
            trace[] += "r"
            _ = result^
        else:
            _ = pending^
    except error:
        comptime assert type_of(error) == Owner
        var raised = rebind_var[Owner](error^)
        trace[] += "e" + String(raised.id)
        _ = raised^
    trace[] += "z"
    return trace[].copy()

def abandoned_stage() -> String:
    var trace = ArcPointer(String())
    var pending = pipeline[IdentityFamily](source(trace)).fold_effect[OptionalFamily](initial(trace))
    trace[] += "d"
    _ = pending^
    return trace[].copy()


@fieldwise_init
struct OriginStep[o: ImmOrigin](Binary):
    comptime First = List[Pointer[Int, Self.o]]
    comptime Second = Int
    comptime Out = Optional[Self.First]
    def call(self, var first: Self.First, var second: Int) -> Self.Out:
        return Optional(first^)
