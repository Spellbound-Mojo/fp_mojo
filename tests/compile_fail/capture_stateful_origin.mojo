# error: origin_of(local)
from fp.data import Capture
@fieldwise_init
struct Fault(Movable):
    var code:Int
@fieldwise_init
struct Other(Movable):
    var code:Int
@fieldwise_init
struct Token(Movable):
    var value:Int
from fp.data import Result
def callback[V:Copyable & Deinitable](mut state:V,var flag:Bool) raises V->V:
    if flag:raise state.copy()
    return state.copy()
def check(anchor:List[Int],local:List[Int]):
    var view=Span(local)
    var other=Span(anchor)
    var adapter=Capture[type_of(view)]().stateful(callback[type_of(view)],view)
    var bad:Result[type_of(other),type_of(other)]=adapter.run(True)
    _=bad^
def main():
    var a:List[Int]=[3]
    var b:List[Int]=[7]
    check(a,b)
