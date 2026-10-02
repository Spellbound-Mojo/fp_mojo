"""Target operation errors stop collection at the exact source-pull boundary."""
from fp.algebra import traverse, ListFamily
from fp.callables import Unary
from std.builtin.rebind import rebind
from std.memory import ArcPointer
from std.testing import assert_equal
from algebra_support.external import PublicMonad
from algebra_support.box import Box, BoxMonad
from algebra_support.iterators import Counted

@fieldwise_init
struct Produce(Unary):
    var calls:ArcPointer[Int]
    comptime Arg=Int
    comptime Out=Box[Int]
    def call(self,var item:Int)->Box[Int]:
        self.calls[]+=1
        return Box(item)

def check[stage:Int]() raises:
    comptime M=PublicMonad[BoxMonad,stage]
    var calls=ArcPointer(Int(0))
    var pulls=0
    var code=0
    try:
        _=traverse[ListFamily,M](Produce(calls),Counted(Pointer(to=pulls),0,5))
    except error:
        comptime assert type_of(error)==Int
        code=rebind[Int](error)
    assert_equal(code,701+stage)
    # A failed map follows one pull and callback; a failed combination precedes any pull.
    assert_equal(pulls,1 if stage==1 else 0)
    assert_equal(calls[],1 if stage==1 else 0)

def main() raises:
    check[1]()
    check[3]()
    print("external target failures: exact map/combination errors and pull boundaries")
