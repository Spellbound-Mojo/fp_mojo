"""Single-value traversal consumes captured owners without Cartesian copies."""
from fp.algebra import Traversable,TraverseContract,OptionalFamily,ResultFamily,ListFamily,traverse
from fp.callables import OnceUnary
from fp.data import Result,Ok,Err
from test_applicative_error_ownership import AEOOwner as Owner
from std.memory import ArcPointer
from std.testing import assert_equal
from std.builtin.rebind import rebind_var

@fieldwise_init
struct Produce(OnceUnary):
    var capture:Owner
    var calls:ArcPointer[Int]
    var fail:Bool
    comptime Arg=Owner
    comptime Out=List[Owner]
    comptime Error=Int
    def call_once(deinit self,var owner:Owner) raises Int ->Self.Out:
        self.calls[]+=1
        if self.fail:raise 901
        owner.value+=self.capture.value
        return ListFamily.pure(owner^)

def check[S:Traversable,V:Movable & Deinitable](var value:V,drops:ArcPointer[Int],present:Bool,fail:Bool) raises where TraverseContract[S,ListFamily,V,Produce].Compatible:
    var captures=ArcPointer(0)
    var calls=ArcPointer(0)
    var code=0
    try:
        _=traverse[S,ListFamily](value^,Produce(Owner(10,captures),calls,fail))
    except error:
        comptime assert type_of(error)==Int
        code=rebind_var[Int](error^)
    assert_equal(code,901 if present and fail else 0)
    assert_equal(calls[],Int(present))
    assert_equal(drops[],Int(present))
    assert_equal(captures[],1)

def main() raises:
    for skip in [False,True]:
        for fail in [False,True]:
            var optional_drops=ArcPointer(0)
            var optional=Optional[Owner]()
            if not skip:optional=Optional(Owner(1,optional_drops))
            check[OptionalFamily](optional^,optional_drops,not skip,fail)
            var result_drops=ArcPointer(0)
            var result:Result[Owner,String]
            if skip:result=Err(String("skip"))
            else:result=Ok(Owner(1,result_drops))
            check[ResultFamily[String]](result^,result_drops,not skip,fail)
            var success_drops=ArcPointer(0)
            var error_drops=ArcPointer(0)
            var owned_error:Result[Owner,Owner]
            if skip:owned_error=Err(Owner(2,error_drops))
            else:owned_error=Ok(Owner(1,success_drops))
            check[ResultFamily[Owner]](owned_error^,success_drops,not skip,fail)
            assert_equal(error_drops[],Int(skip))
