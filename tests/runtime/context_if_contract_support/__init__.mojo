from fp.algebra import IfContract, Monad, IdentityFamily, OptionalFamily, ListFamily, ResultFamily, if_effect, pure
from fp.functions import pipeline, piped, Pipeline
from fp.callables import ThunkContract, Thunk, OnceThunk
from fp.effects import Reader, run
from algebra_support.box import BoxMonad
from std.testing import assert_equal

def forward[I: Monad, V: Movable & Deinitable, L: ThunkContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var left: L, var right: R, var source: V) raises IfContract[I,V,L,R].Error -> IfContract[I,V,L,R].Out where IfContract[I,V,L,R].Compatible:
    return if_effect[I](left^, right^, source^)

def fluent[I: Monad, V: Movable & Deinitable, L: ThunkContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var left: L, var right: R, var source: V) raises IfContract[I,V,L,R].Error -> IfContract[I,V,L,R].Out where IfContract[I,V,L,R].Compatible:
    return piped(source^).if_effect[G=I](left^, right^).get()

def selected[I: Monad, V: Movable & Deinitable, L: ThunkContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var left: L, var right: R, var source: V) raises IfContract[I,V,L,R].Error -> Pipeline[I,IfContract[I,V,L,R].Out] where IfContract[I,V,L,R].Compatible:
    return pipeline[I](source^).if_effect(left^, right^)

@fieldwise_init
struct Factory[G: Monad](Thunk):
    var value: Int
    comptime Out = Self.G.Pure[Int]
    def call(self) -> Self.Out: return pure[Self.G](self.value)

@fieldwise_init
struct Once[G: Monad](OnceThunk):
    var value: Int
    comptime Out = Self.G.Pure[Int]
    def call_once(deinit self) -> Self.Out: return pure[Self.G](self.value)


from fp.algebra import Monad, IdentityFamily, OptionalFamily, ListFamily, ResultFamily, if_effect, pure
from fp.callables import OnceThunk, MutableThunk
from fp.functions import pipeline, piped
from fp.effects import Reader, run
from fp.data import Result, Err
from std.memory import ArcPointer
from std.builtin.rebind import rebind_var
from test_context_failure_forwarding_ownership import Owner

@fieldwise_init
struct OwnedFactory[G: Monad, fail: Bool](OnceThunk, MutableThunk):
    var owner: Owner
    var calls: Int
    comptime Out = Self.G.Pure[Int]
    comptime Error = Owner
    def call_once(deinit self) raises Owner -> Self.Out:
        return self.call_mut()
    def call_mut(mut self) raises Owner -> Self.Out:
        self.calls += 1
        self.owner.trace[] += "c" + String(self.owner.id) + String(self.calls)
        if Self.fail: raise Owner(7, self.owner.trace)
        return pure[Self.G](self.owner.id * 10 + self.calls)

def immediate[G: Monad, route: Int, truth: Bool, absent: Bool, fail: Bool]() -> String where IfContract[G, G.Pure[Bool], OwnedFactory[G,fail], OwnedFactory[G,fail]].Compatible:
    var trace = ArcPointer(String())
    var left = OwnedFactory[G, fail](Owner(1,trace),0)
    var right = OwnedFactory[G, fail](Owner(2,trace),0)
    var condition = pure[G](truth)
    comptime if absent:
        comptime if G == OptionalFamily:
            comptime assert G.Pure[Bool] == Optional[Bool]
            condition = rebind_var[G.Pure[Bool]](Optional[Bool]())
        else:
            comptime assert G.Pure[Bool] == Result[Bool,String]
            condition = rebind_var[G.Pure[Bool]](Result[Bool,String](Err(String("skip"))))
    try:
        comptime if route == 0:
            var result = if_effect[G](left^,right^,condition^)
            trace[] += "r"
            _ = result^
        elif route == 1:
            var result = pipeline[G](condition^).if_effect(left^,right^).get()
            trace[] += "r"
            _ = result^
        else:
            var result = piped(condition^).if_effect[G=G](left^,right^).get()
            trace[] += "r"
            _ = result^
    except error:
        trace[] += "e"
        _ = error^
    trace[] += "z"
    return trace[].copy()

def branched() -> String:
    var trace = ArcPointer(String())
    try:
        var result = pipeline(List[Bool]([True,False,True])).if_effect(OwnedFactory[ListFamily,False](Owner(1,trace),0),OwnedFactory[ListFamily,False](Owner(2,trace),0)).get()
        for value in result: trace[] += "v" + String(value)
    except error:
        trace[] += "e"
    trace[] += "z"
    return trace[].copy()

def deferred[execute: Bool, fail: Bool]() -> String:
    comptime G = Reader[Int]
    var trace = ArcPointer(String())
    var pending = pipeline[G](pure[G](True)).if_effect(OwnedFactory[G,fail](Owner(1,trace),0),OwnedFactory[G,fail](Owner(2,trace),0)).get()
    trace[] += "d"
    try:
        if execute:
            var result = run[G](pending^,0)
            trace[] += "v" + String(result)
        else: _ = pending^
    except error:
        trace[] += "e"
        _ = error^
    trace[] += "z"
    return trace[].copy()

@fieldwise_init
struct PointerFactory[o: ImmOrigin](OnceThunk):
    var pointer: Pointer[Int, Self.o]
    comptime Out = Optional[Pointer[Int, Self.o]]
    def call_once(deinit self) -> Self.Out:
        return Optional(self.pointer)

@fieldwise_init
struct PointerFailure[o: ImmOrigin](OnceThunk):
    var pointer: Pointer[Int, Self.o]
    comptime Out = Optional[Int]
    comptime Error = Pointer[Int, Self.o]
    def call_once(deinit self) raises Self.Error -> Self.Out:
        raise self.pointer

@fieldwise_init
struct StringFactory(Thunk):
    comptime Out = Optional[String]
    def call(self) -> Self.Out:
        return Optional(String("text"))

@fieldwise_init
struct ErrorFactory[E: Movable & Deinitable](Thunk):
    comptime Out = Optional[Int]
    comptime Error = Self.E
    def call(self) raises Self.Error -> Self.Out:
        return Optional(1)

from fp.functions import Identity

@fieldwise_init
struct MappedReader(Thunk):
    comptime G = Reader[Int]
    comptime Out = Self.G.Mapped[Self.G.Pure[Int], Identity[Int]]
    def call(self) -> Self.Out:
        return Self.G.map(Identity[Int](), Self.G.pure(9))

# Preserve the predicates existing generic free/fluent callers already forward.
def legacy_forward[I: Monad, V: Movable & Deinitable, L: ThunkContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var left: L, var right: R, var source: V
) raises IfContract[I,V,L,R].Error -> IfContract[I,V,L,R].Out where I.Element[V] == Bool and I.Element[L.Out] == I.Element[R.Out] and I.CarrierCompatible[V] and I.CarrierCompatible[L.Out] and I.CarrierCompatible[R.Out]:
    return if_effect[I](left^, right^, source^)

def legacy_fluent[I: Monad, V: Movable & Deinitable, L: ThunkContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var left: L, var right: R, var source: V
) raises IfContract[I,V,L,R].Error -> IfContract[I,V,L,R].Out where I.Element[V] == Bool and I.Element[L.Out] == I.Element[R.Out] and I.CarrierCompatible[V] and I.CarrierCompatible[L.Out] and I.CarrierCompatible[R.Out]:
    return piped(source^).if_effect[G=I](left^, right^).get()


@fieldwise_init
struct Missing(ThunkContract, Movable):
    comptime Out = Optional[Int]


def legacy_selected[I: Monad, V: Movable & Deinitable, L: ThunkContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var left: L, var right: R, var source: V
) raises IfContract[I,V,L,R].Error -> IfContract[I,V,L,R].Out where IfContract[I,V,L,R].ShapeCompatible and IfContract[I,V,L,R].NativeErrorsCompatible and IfContract[I,V,L,R].FamilyCompatible:
    return pipeline[I](source^).if_effect(left^,right^).get()


def checked_forward[I: Monad, V: Movable & Deinitable, L: ThunkContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var left: L, var right: R, var source: V
) raises IfContract[I,V,L,R].Error -> IfContract[I,V,L,R].Out where IfContract[I,V,L,R].InvocationCompatible:
    return forward[I](left^,right^,source^)


def expanded_forward[I: Monad, V: Movable & Deinitable, L: ThunkContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var left: L, var right: R, var source: V
) raises IfContract[I,V,L,R].Error -> IfContract[I,V,L,R].Out where IfContract[I,V,L,R].ShapeCompatible and IfContract[I,V,L,R].NativeErrorsCompatible and IfContract[I,V,L,R].FamilyCompatible:
    return forward[I](left^,right^,source^)
