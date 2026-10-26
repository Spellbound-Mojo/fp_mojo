"""Generic branch factories retain their exact native error types."""
from fp.functions import pipeline
from std.testing import assert_equal

def choose[A:Movable & Deinitable,E:Movable & Deinitable,o:ImmOrigin,q:ImmOrigin,//,L:def() raises E -> Optional[A],R:def() raises E -> Optional[A]](ref[o] left:L,ref[q] right:R,var condition:Optional[Bool]) raises E -> Optional[A]:
    return pipeline(condition^).raising[E]().if_effect(left,right).get()
def main() raises:
    def yes() -> Optional[Int]: return Optional(1)
    def no() -> Optional[Int]: return Optional(2)
    assert_equal(choose(yes,no,Optional(True)).value(),1)
    def fail() raises Int -> Optional[Int]: raise 7
    var code=0
    try: _ = choose(fail,fail,Optional(False))
    except e: code=e
    assert_equal(code,7)
    views(List[Int]([1,2]),List[Int]([3]))

def views(owner:List[Int],errors:List[Int]) raises:
    comptime View=type_of(Span(owner))
    comptime Failure=type_of(Span(errors))
    var view=Span(owner)
    var failure=Span(errors)
    def present() {view} -> Optional[View]: return Optional(view)
    assert_equal(choose(present,present,Optional(True)).value().unsafe_ptr()==Span(owner).unsafe_ptr(),True)
    def fail() raises Failure {failure} -> Optional[View]: raise failure
    var caught=False
    try: _ = choose(fail,fail,Optional(False))
    except error: caught=error.unsafe_ptr()==Span(errors).unsafe_ptr()
    assert_equal(caught,True)
