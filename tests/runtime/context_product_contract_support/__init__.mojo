from fp.algebra import Applicative, IdentityFamily, OptionalFamily, ResultFamily, product, pure
from fp.algebra.contracts import ProductContract
from fp.functions import pipeline, Pipeline
from fp.effects import Reader, run
from fp.data import Result, Err
from std.memory import ArcPointer
from std.builtin.rebind import rebind_var
from test_context_failure_forwarding_ownership import Owner

def forward[I: Applicative, V: Movable & Deinitable, W: Movable & Deinitable](var left: V, var right: W
) raises ProductContract[I,V,W].Error -> ProductContract[I,V,W].Out where ProductContract[I,V,W].Compatible:
    return product[I](left^, right^)

def fluent[I: Applicative, V: Movable & Deinitable, W: Movable & Deinitable](var left: V, var right: W
) raises ProductContract[I,V,W].Error -> ProductContract[I,V,W].Out where ProductContract[I,V,W].Compatible:
    return pipeline[I](left^).product(right^).get()

def selected[I: Applicative, V: Movable & Deinitable, W: Movable & Deinitable](var left: V, var right: W
) raises ProductContract[I,V,W].Error -> Pipeline[I,ProductContract[I,V,W].Out] where ProductContract[I,V,W].Compatible:
    return pipeline[I](left^).product(right^)

def legacy[I: Applicative, V: Movable & Deinitable, W: Movable & Deinitable](var left: V, var right: W
) raises ProductContract[I,V,W].Error -> ProductContract[I,V,W].Out where ProductContract[I,V,W].OperationCompatible:
    return product[I](left^, right^)



def immediate[I: Applicative, route: Int, skip_left: Bool, skip_right: Bool]() -> String where ProductContract[I,I.Pure[Owner],I.Pure[Owner]].Compatible:
    var trace = ArcPointer(String())
    var left = pure[I](Owner(1,trace))
    var right = pure[I](Owner(2,trace))
    comptime if skip_left:
        comptime if I == OptionalFamily:
            comptime assert I.Pure[Owner] == Optional[Owner]
            left = rebind_var[I.Pure[Owner]](Optional[Owner]())
        else:
            comptime assert I.Pure[Owner] == Result[Owner,String]
            left = rebind_var[I.Pure[Owner]](Result[Owner,String](Err(String("left"))))
    comptime if skip_right:
        comptime if I == OptionalFamily:
            comptime assert I.Pure[Owner] == Optional[Owner]
            right = rebind_var[I.Pure[Owner]](Optional[Owner]())
        else:
            comptime assert I.Pure[Owner] == Result[Owner,String]
            right = rebind_var[I.Pure[Owner]](Result[Owner,String](Err(String("right"))))
    try:
        comptime if route == 0:
            var result = product[I](left^,right^)
            trace[] += "r"
            _ = result^
        elif route == 1:
            var result = pipeline[I](left^).product(right^).get()
            trace[] += "r"
            _ = result^
        else:
            var result = pipeline[I](left^).product(right^).get()
            trace[] += "r"
            _ = result^
    except error:
        trace[] += "e"
        _ = error^
    trace[] += "z"
    return trace[].copy()

def delayed[execute: Bool]() -> String:
    comptime I = Reader[Int]
    var trace = ArcPointer(String())
    var pending = pipeline[I](pure[I](Owner(1,trace))).product(pure[I](Owner(2,trace))).get()
    trace[] += "d"
    if execute:
        var result = run[I](pending^,0)
        trace[] += "r"
        _ = result^
    else: _ = pending^
    trace[] += "z"
    return trace[].copy()
