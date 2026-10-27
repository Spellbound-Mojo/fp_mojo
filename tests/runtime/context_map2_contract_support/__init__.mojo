from fp.algebra import Map2Contract, Applicative, IdentityFamily, OptionalFamily, ListFamily, ResultFamily, map2, pure
from fp.callables import BinaryContract
from fp.functions import pipeline, Pipeline, piped
from fp.effects import Reader, run
from context_combination_admission_support import Add, OnceAdd, Stateful, MoveLeft, MoveRight, MoveState
from algebra_support.box import BoxMonad
from std.testing import assert_equal

def forward[I: Applicative, V: Movable & Deinitable, W: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](var function: F, var left: V, var right: W
) raises Map2Contract[I,V,W,F].Error -> Map2Contract[I,V,W,F].Out where Map2Contract[I,V,W,F].Compatible:
    return map2[I](function^, left^, right^)

def fluent[I: Applicative, V: Movable & Deinitable, W: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](var function: F, var left: V, var right: W
) raises Map2Contract[I,V,W,F].Error -> Map2Contract[I,V,W,F].Out where Map2Contract[I,V,W,F].Compatible:
    return piped(left^).map2[I](right^, function^).get()

def selected[I: Applicative, V: Movable & Deinitable, W: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](var function: F, var left: V, var right: W
) raises Map2Contract[I,V,W,F].Error -> Pipeline[I,Map2Contract[I,V,W,F].Out] where Map2Contract[I,V,W,F].Compatible:
    return pipeline[I](left^).map2(right^, function^)

def legacy[I: Applicative, V: Movable & Deinitable, W: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](var function: F, var left: V, var right: W
) raises Map2Contract[I,V,W,F].Error -> Map2Contract[I,V,W,F].Out where Map2Contract[I,V,W,F].OperationCompatible:
    return map2[I](function^, left^, right^)


from fp.algebra import Applicative, Map2Contract, IdentityFamily, OptionalFamily, ResultFamily, map2, pure
from fp.callables import OnceBinary
from fp.functions import pipeline, piped
from fp.effects import Reader, run
from fp.data import Result, Err
from algebra_support.box import BoxMonad
from std.memory import ArcPointer
from std.builtin.rebind import rebind_var
from test_context_failure_forwarding_ownership import Owner

@fieldwise_init
struct Combine[fail: Bool](OnceBinary):
    var capture: Owner
    comptime First = Owner
    comptime Second = Owner
    comptime Out = Owner
    comptime Error = Owner
    def call_once(deinit self, var first: Owner, var second: Owner) raises Owner -> Owner:
        self.capture.trace[] += "c"
        if Self.fail: raise Owner(7,self.capture.trace)
        first.id += second.id
        return first^

def immediate[I: Applicative, route: Int, skip: Bool, fail: Bool]() -> String where Map2Contract[I,I.Pure[Owner],I.Pure[Owner],Combine[fail]].Compatible:
    var trace = ArcPointer(String())
    var left = pure[I](Owner(1,trace))
    var right = pure[I](Owner(2,trace))
    var function = Combine[fail](Owner(9,trace))
    comptime if skip:
        comptime if I == OptionalFamily:
            comptime assert I.Pure[Owner] == Optional[Owner]
            left = rebind_var[I.Pure[Owner]](Optional[Owner]())
        else:
            comptime assert I.Pure[Owner] == Result[Owner,String]
            left = rebind_var[I.Pure[Owner]](Result[Owner,String](Err(String("skip"))))
    try:
        comptime if route == 0:
            var result = map2[I](function^,left^,right^)
            trace[] += "r"
            _ = result^
        elif route == 1:
            var result = pipeline[I](left^).map2(right^,function^).get()
            trace[] += "r"
            _ = result^
        else:
            var result = piped(left^).map2[I](right^,function^).get()
            trace[] += "r"
            _ = result^
    except error:
        trace[] += "e"
        _ = error^
    trace[] += "z"
    return trace[].copy()

def delayed[execute: Bool, fail: Bool]() -> String:
    comptime I = Reader[Int]
    var trace = ArcPointer(String())
    var pending = pipeline[I](pure[I](Owner(1,trace))).map2(pure[I](Owner(2,trace)),Combine[fail](Owner(9,trace))).get()
    trace[] += "d"
    try:
        if execute:
            var result = run[I](pending^,0)
            trace[] += "r"
            _ = result^
        else: _ = pending^
    except error:
        trace[] += "e"
        _ = error^
    trace[] += "z"
    return trace[].copy()

@fieldwise_init
struct Keep[o: ImmOrigin](OnceBinary):
    comptime First = Pointer[Int,Self.o]
    comptime Second = Int
    comptime Out = Self.First
    def call_once(deinit self, var first: Self.First, var second: Int) -> Self.Out:
        return first

@fieldwise_init
struct Raise[o: ImmOrigin](OnceBinary):
    var pointer: Pointer[Int,Self.o]
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    comptime Error = Pointer[Int,Self.o]
    def call_once(deinit self, var first: Int, var second: Int) raises Self.Error -> Int:
        raise self.pointer
