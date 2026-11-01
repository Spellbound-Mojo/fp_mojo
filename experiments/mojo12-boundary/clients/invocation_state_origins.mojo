from fp._binding_state import Capture
from fp.data import Result
from std.testing import assert_equal

def value[T: Copyable & Deinitable](mut state: T, var fail: Bool) raises T -> T:
    if fail: raise state.copy()
    return state.copy()
def check(owner: List[Int]) raises:
    var view=Span(owner)
    comptime View=type_of(view)
    var adapter=Capture[View].stateful(value[View],view)
    var success=adapter.run(False)
    comptime assert type_of(success)==Result[View,View]
    assert_equal(Pointer(to=success._ok().value[0])==Pointer(to=owner[0]),True)
    var error=adapter.run(True)
    assert_equal(Pointer(to=error._err().value[1])==Pointer(to=owner[1]),True)
    var returned=adapter^.into_state()
    assert_equal(Pointer(to=returned[0])==Pointer(to=owner[0]),True)
def main() raises:
    var owner:List[Int]=[3,7]
    check(owner)
