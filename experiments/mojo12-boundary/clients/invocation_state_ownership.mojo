from fp._binding_state import Capture
from fp.data import Result
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct Owner(Movable):
    var value:Int
    var drops:ArcPointer[Int]
    def __deinit__(deinit self):self.drops[]+=1
@fieldwise_init
struct Fault(Movable):
    var code:Int
def callback(mut state:Owner,var payload:Owner) raises Fault -> Owner:
    state.value+=payload.value
    if payload.value<0:raise Fault(state.value)
    return payload^
def exercise(sd:ArcPointer[Int],pd:ArcPointer[Int]) raises:
    var adapter=Capture[Fault].stateful(callback,Owner(1,sd))
    var success=adapter.run(Owner(2,pd))
    assert_equal(success._ok().value.value,2)
    assert_equal(pd[],0)
    _=success^
    assert_equal(pd[],1)
    assert_equal(adapter.run(Owner(-4,pd))._err().value.code,-1)
    assert_equal(pd[],2)
    var moved=adapter^
    assert_equal(moved.state().value,-1)
    assert_equal(sd[],0)
    _=moved^
def main() raises:
    var sd=ArcPointer(0)
    var pd=ArcPointer(0)
    exercise(sd,pd)
    assert_equal(sd[],1)
    assert_equal(pd[],2)
    var unused=Capture[Fault].stateful(callback,Owner(9,sd))
    _=unused^
    assert_equal(sd[],2)
    assert_equal(pd[],2)
