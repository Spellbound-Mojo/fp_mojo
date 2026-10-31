from fp.algebra import Applicative,ListFamily,IdentityFamily,OptionalFamily,ResultFamily,ValidationFamily,ListMonoid,TraverseContract,traverse
from fp.callables import MutableUnary
from test_applicative_error_ownership import AEOOwner as Owner
from std.memory import ArcPointer
from std.testing import assert_equal
from std.builtin.rebind import rebind_var

@fieldwise_init
struct Produce[I:Applicative](MutableUnary):
    var capture:Owner
    var calls:ArcPointer[Int]
    var fail:Bool
    comptime Arg=Owner
    comptime Out=Self.I.Pure[Owner]
    comptime Error=Int
    def call_mut(mut self,var value:Owner) raises Int ->Self.Out:
        self.calls[]+=1
        if self.fail and value.value==2:raise 83
        value.value+=self.capture.value
        return Self.I.pure(value^)

def check[I:Applicative]() raises where TraverseContract[ListFamily,I,List[Owner],Produce[I]].Compatible:
    comptime assert not conforms_to(Produce[I],Copyable)
    for fail in [False,True]:
        var inputs=ArcPointer(0)
        var captures=ArcPointer(0)
        var calls=ArcPointer(0)
        var values=List[Owner]()
        for value in range(1,4):values.append(Owner(value,inputs))
        var code=0
        try:_=traverse[I, ListFamily](values^,Produce[I](Owner(10,captures),calls,fail))
        except error:
            comptime assert type_of(error)==Int
            code=rebind_var[Int](error^)
        assert_equal(code,83 if fail else 0)
        assert_equal(calls[],2 if fail else 3)
        assert_equal(inputs[],3)
        assert_equal(captures[],1)

def main() raises:
    check[IdentityFamily]()
    check[OptionalFamily]()
    check[ResultFamily[String]]()
    check[ValidationFamily[ListMonoid[String]]]()
