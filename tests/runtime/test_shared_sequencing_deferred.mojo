"""Shared deferred factories preserve timing, raised errors and native borrowing."""
from fp.callables import Thunk
from fp.effects import Reader,run
from fp.functions import pipeline
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Factory(Thunk):
    comptime Out=Reader[Int].Pure[Int]
    comptime Error=Int
    var calls:ArcPointer[Int]
    var fail:Bool
    def call(self) raises Int -> Self.Out:
        self.calls[]+=1
        if self.fail:raise 7
        return Reader[Int].pure(9)

def main() raises:
    comptime R=Reader[Int]
    var calls=ArcPointer(0)
    var factory=Factory(calls,False)
    var pending=pipeline[R](R.pure(4)).followed_by(factory).get()
    assert_equal(calls[],0)
    var value:Int
    try: value=run[R](pending^,0)
    except:raise Error("unexpected factory failure")
    assert_equal(value,9)
    assert_equal(calls[],1)
    var failed=pipeline[R](R.pure(4)).before(factory).get()
    factory.fail=True
    assert_equal(calls[],1)
    var raised=0
    try: _=run[R](failed^,0)
    except error:
        comptime assert type_of(error)==Int
        raised=error
    assert_equal(raised,7)
    assert_equal(calls[],2)
    assert_equal(factory.fail,True)
