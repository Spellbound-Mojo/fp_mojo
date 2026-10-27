from fp.algebra import OptionalFamily
from fp.data import Result, Err
from std.memory import ArcPointer
from std.builtin.rebind import rebind_var
from test_context_failure_forwarding_ownership import Owner
from context_branch_admission_support import MoveState
from fp.callables import UnaryContract

from fp.algebra import ApContract, Applicative, ap, pure
from fp.functions import pipeline, piped, Pipeline
from fp.callables import Unary, OnceUnary, MutableUnary
from fp.effects import Reader, run

@fieldwise_init
struct Plus(Unary, Copyable):
    var amount: Int
    comptime Arg = Int
    comptime Out = Int
    def call(self, var value: Int) -> Int:
        return value + self.amount

@fieldwise_init
struct Consuming(OnceUnary):
    var amount: Int
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var value: Int) -> Int:
        return value + self.amount

@fieldwise_init
struct Stateful(MutableUnary, Copyable):
    var amount: Int
    comptime Arg = Int
    comptime Out = Int
    def call_mut(mut self, var value: Int) -> Int:
        self.amount += 1
        return value + self.amount

@fieldwise_init
struct CopyOnce(OnceUnary, Copyable):
    var amount: Int
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var value: Int) -> Int:
        return value + self.amount

def forward[I: Applicative, V: Movable & Deinitable, W: Movable & Deinitable](var callbacks: V, var values: W
) raises ApContract[I,V,W].Error -> ApContract[I,V,W].Out where ApContract[I,V,W].Compatible:
    return ap[I](callbacks^, values^)

def fluent[I: Applicative, V: Movable & Deinitable, W: Movable & Deinitable](var callbacks: V, var values: W
) raises ApContract[I,V,W].Error -> ApContract[I,V,W].Out where ApContract[I,V,W].Compatible:
    return piped(callbacks^).ap[I](values^).get()

def selected[I: Applicative, V: Movable & Deinitable, W: Movable & Deinitable](var callbacks: V, var values: W
) raises ApContract[I,V,W].Error -> Pipeline[I,ApContract[I,V,W].Out] where ApContract[I,V,W].Compatible:
    return pipeline[I](callbacks^).ap(values^)

def legacy[I: Applicative, V: Movable & Deinitable, W: Movable & Deinitable](var callbacks: V, var values: W
) raises ApContract[I,V,W].Error -> ApContract[I,V,W].Out where ApContract[I,V,W].OperationCompatible:
    return ap[I](callbacks^, values^)

@fieldwise_init
struct Apply[fail: Bool](OnceUnary):
    var capture: Owner
    comptime Arg = Owner
    comptime Out = Owner
    comptime Error = Owner
    def call_once(deinit self, var value: Owner) raises Owner -> Owner:
        self.capture.trace[] += "c"
        if Self.fail:
            raise Owner(7,self.capture.trace)
        return value^

def immediate[I: Applicative,route: Int,skip_left: Bool,skip_right: Bool,fail: Bool]() -> String where ApContract[I,I.Pure[Apply[fail]],I.Pure[Owner]].Compatible:
    var trace = ArcPointer(String())
    var left = pure[I](Apply[fail](Owner(9,trace)))
    var right = pure[I](Owner(2,trace))
    comptime if skip_left:
        comptime if I == OptionalFamily:
            comptime assert I.Pure[Apply[fail]] == Optional[Apply[fail]]
            left = rebind_var[I.Pure[Apply[fail]]](Optional[Apply[fail]]())
        else:
            comptime assert I.Pure[Apply[fail]] == Result[Apply[fail],String]
            left = rebind_var[I.Pure[Apply[fail]]](Result[Apply[fail],String](Err(String("left"))))
    comptime if skip_right:
        comptime if I == OptionalFamily:
            comptime assert I.Pure[Owner] == Optional[Owner]
            right = rebind_var[I.Pure[Owner]](Optional[Owner]())
        else:
            comptime assert I.Pure[Owner] == Result[Owner,String]
            right = rebind_var[I.Pure[Owner]](Result[Owner,String](Err(String("right"))))
    try:
        comptime if route == 0:
            var result = ap[I](left^,right^)
            trace[] += "r"
            _ = result^
        elif route == 1:
            var result = pipeline[I](left^).ap(right^).get()
            trace[] += "r"
            _ = result^
        else:
            var result = piped(left^).ap[I](right^).get()
            trace[] += "r"
            _ = result^
    except error:
        trace[] += "e"
        _ = error^
    trace[] += "z"
    return trace[].copy()

def delayed[execute: Bool,fail: Bool]() -> String:
    comptime I = Reader[Int]
    var trace = ArcPointer(String())
    var pending = pipeline[I](pure[I](Apply[fail](Owner(9,trace)))).ap(pure[I](Owner(2,trace))).get()
    trace[] += "d"
    if execute:
        try:
            var result = run[I](pending^,0)
            trace[] += "r"
            _ = result^
        except error:
            trace[] += "e"
            _ = error^
    else:
        _ = pending^
    trace[] += "z"
    return trace[].copy()

@fieldwise_init
struct View[o: ImmOrigin](OnceUnary):
    var fail: Bool
    comptime Arg = Pointer[Int,Self.o]
    comptime Out = Pointer[Int,Self.o]
    comptime Error = Pointer[Int,Self.o]
    def call_once(deinit self, var value: Self.Arg) raises Self.Error -> Self.Out:
        if self.fail:
            raise value
        return value

@fieldwise_init
struct Missing(UnaryContract, Movable):
    comptime Arg = Int
    comptime Out = Int

@fieldwise_init
struct KeepMove(Unary, Copyable):
    comptime Arg = MoveState
    comptime Out = Int
    def call(self, var value: Self.Arg) -> Int:
        return 0
