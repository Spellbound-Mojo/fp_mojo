from fp.data import Capture
from std.testing import assert_equal
@fieldwise_init
struct CaptureStateViewsState(Movable):
    var value:Int
def callback(mut state:CaptureStateViewsState,var text:String)->Int:
    state.value+=text.byte_length()
    return state.value
def main() raises:
    var adapter=Capture[Never]().stateful(callback,CaptureStateViewsState(1))
    var view=Pointer(to=adapter.state())
    assert_equal(adapter.run(String("a"))._ok().value,2)
    assert_equal(view[].value,2)
    var returned=adapter^.into_state()
    assert_equal(returned.value,2)
