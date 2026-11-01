from fp.functions import Identity,flow,compose
from fp.functions.composition import Identity as CompositionIdentity
from fp.callables._identity import Identity as CallableIdentity
from fp.callables import call_once
from test_applicative_error_ownership import AEOOwner as Owner
from std.memory import ArcPointer
from std.testing import assert_equal

def generic[T:Movable & Deinitable](var value:T)->T:
    return Identity[T]()(value^)

def origins(anchor:List[Int]) raises:
    var view=generic(Span(anchor))
    assert_equal(view.unsafe_ptr()==Span(anchor).unsafe_ptr(),True)

def main() raises:
    comptime assert Identity[Owner]==CompositionIdentity[Owner]
    comptime assert Identity[Owner]==CallableIdentity[Owner]
    comptime assert type_of(flow[Owner]())==Identity[Owner]
    comptime assert type_of(compose[Owner]())==Identity[Owner]
    comptime assert Identity[Owner].Error==Never
    var drops=ArcPointer(0)
    var owner=call_once(flow[Owner](),Owner(7,drops))
    assert_equal(drops[],0)
    var moved=generic(owner^)
    assert_equal(moved.value,7)
    assert_equal(drops[],0)
    _=moved^
    assert_equal(drops[],1)
    origins([1,2])
