from fp.algebra import Monad,ListFamily,IdentityFamily,OptionalFamily,ResultFamily,TraverseContract,traverse
from fp.callables import MutableUnary
from fp.effects import WriterT
from test_applicative_error_ownership import AEOOwner as Owner
from test_writer_capabilities import WCOwnedLog,WCMoveLogMonoid
from std.memory import ArcPointer
from std.testing import assert_equal
from std.builtin.rebind import rebind_var

@fieldwise_init
struct Produce[M:Monad](MutableUnary):
    var capture:Owner
    var calls:ArcPointer[Int]
    var logs:ArcPointer[Int]
    var fail:Bool
    comptime I=WriterT[Self.M,WCMoveLogMonoid]
    comptime Arg=Owner
    comptime Out=Self.I.Pure[Owner]
    comptime Error=Int
    def call_mut(mut self,var value:Owner) raises Int ->Self.Out:
        self.calls[]+=1
        if self.fail and value.value==2:raise 83
        value.value+=self.capture.value
        return Self.Out(Self.M.pure(Tuple(WCOwnedLog(String(value.value),self.logs),value^)))

def check[M:Monad]() raises where TraverseContract[ListFamily,WriterT[M,WCMoveLogMonoid],List[Owner],Produce[M]].Compatible:
    comptime I=WriterT[M,WCMoveLogMonoid]
    comptime assert not conforms_to(Produce[M],Copyable)
    comptime assert not conforms_to(WCOwnedLog,Copyable)
    for fail in [False,True]:
        var inputs=ArcPointer(0)
        var captures=ArcPointer(0)
        var calls=ArcPointer(0)
        var logs=ArcPointer(0)
        var values=List[Owner]()
        for value in range(1,4):values.append(Owner(value,inputs))
        var code=0
        try:_=traverse[ListFamily,I](values^,Produce[M](Owner(10,captures),calls,logs,fail))
        except error:
            comptime assert type_of(error)==Int
            code=rebind_var[Int](error^)
        assert_equal(code,83 if fail else 0)
        assert_equal(calls[],2 if fail else 3)
        assert_equal(inputs[],3)
        assert_equal(captures[],1)
        assert_equal(logs[],1 if fail else 3)

def main() raises:
    check[IdentityFamily]()
    check[OptionalFamily]()
    check[ResultFamily[String]]()
    comptime assert not WriterT[ListFamily,WCMoveLogMonoid].CollectCompatible[List[Owner],Produce[ListFamily]]
