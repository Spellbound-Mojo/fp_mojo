from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct CaptureStateOwnershipOwner(Movable):
    var value:Int
    var drops:ArcPointer[Int]
    def __deinit__(deinit self):self.drops[]+=1
@fieldwise_init
struct CaptureStateOwnershipFault(Movable):
    var code:Int
def callback(mut state:CaptureStateOwnershipOwner,var payload:CaptureStateOwnershipOwner) raises CaptureStateOwnershipFault -> CaptureStateOwnershipOwner:
    state.value+=payload.value
    if payload.value<0:raise CaptureStateOwnershipFault(state.value)
    return payload^
def exercise(sd:ArcPointer[Int],pd:ArcPointer[Int]) raises:
    var adapter=Capture[CaptureStateOwnershipFault]().stateful(callback,CaptureStateOwnershipOwner(1,sd))
    var success=adapter.run(CaptureStateOwnershipOwner(2,pd))
    assert_equal(success._ok().value.value,2)
    assert_equal(pd[],0)
    _=success^
    assert_equal(pd[],1)
    assert_equal(adapter.run(CaptureStateOwnershipOwner(-4,pd))._err().value.code,-1)
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
    var unused=Capture[CaptureStateOwnershipFault]().stateful(callback,CaptureStateOwnershipOwner(9,sd))
    _=unused^
    assert_equal(sd[],2)
    assert_equal(pd[],2)
