from fp.algebra import Monad,IdentityFamily,OptionalFamily,ResultFamily,ListFamily,StringMonoid,TraverseContract,traverse
from fp.callables import Unary
from fp.effects import WriterT,writer,run_writer
from std.testing import assert_equal

@fieldwise_init
struct Logged[M:Monad](Unary):
    comptime I=WriterT[Self.M,StringMonoid]
    comptime Arg=Int
    comptime Out=Self.I.Pure[Int]
    def call(self,var value:Int)->Self.Out:
        return Self.Out(Self.M.pure(Tuple(String(value),value+1)))

def collect[M:Monad]() raises TraverseContract[ListFamily,WriterT[M,StringMonoid],List[Int],Logged[M]].Error ->TraverseContract[ListFamily,WriterT[M,StringMonoid],List[Int],Logged[M]].Out where TraverseContract[ListFamily,WriterT[M,StringMonoid],List[Int],Logged[M]].Compatible:
    return traverse[WriterT[M,StringMonoid], ListFamily](List[Int]([1,2]),Logged[M]())

def main() raises:
    comptime W=WriterT[IdentityFamily,StringMonoid]
    comptime O=WriterT[OptionalFamily,StringMonoid]
    comptime R=WriterT[ResultFamily[String],StringMonoid]
    comptime L=WriterT[ListFamily,StringMonoid]
    var bare=run_writer[W](collect[IdentityFamily]())
    assert_equal(bare[0],"12")
    assert_equal(bare[1],[2,3])
    var optional_carrier=run_writer[O](collect[OptionalFamily]())
    var optional=optional_carrier.take()
    assert_equal(optional[0],"12")
    assert_equal(optional[1],[2,3])
    var result=run_writer[R](collect[ResultFamily[String]]())
    assert_equal(result._ok().value[0],"12")
    assert_equal(result._ok().value[1],[2,3])
    var branches=run_writer[L](collect[ListFamily]())
    assert_equal(branches[0][0],"12")
    assert_equal(branches[0][1],[2,3])
