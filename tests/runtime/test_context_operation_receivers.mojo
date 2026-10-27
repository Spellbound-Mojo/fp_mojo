"""Checked operation wrappers reject missing receivers and preserve family semantics."""
from fp.algebra import OptionalFamily, ListFamily, MapContract, BindContract, CombineContract, Map2Contract, ProductContract
from fp.callables import MutableUnary
from fp.functions import Identity
from fp.effects import Reader, run
from std.testing import assert_equal
from std.memory import ArcPointer
from algebra_support.external import PublicMonad
from context_operation_receiver_support import MissingMap, MissingBind, MissingBinary, MissingThunk, Echo, Present, Add, Next, checked_map, checked_bind, checked_combine, forwarding
from test_context_selection_contracts import Token, Pending
from test_context_operation_contracts import Present as PresentView

@fieldwise_init
struct Counter(MutableUnary):
    var calls: Int
    comptime Arg = Int
    comptime Out = Int
    def call_mut(mut self, var value: Int) -> Int:
        self.calls += 1
        return value + self.calls

def origins(owner: List[Int]) raises:
    comptime View = type_of(Span(owner))
    var mapped = checked_map[OptionalFamily](Optional(Span(owner)),Identity[View]())
    assert_equal(mapped.value().unsafe_ptr() == Span(owner).unsafe_ptr(),True)
    var bound = checked_bind[OptionalFamily](mapped^,PresentView[View]())
    assert_equal(bound.value().unsafe_ptr() == Span(owner).unsafe_ptr(),True)

def main() raises:
    forwarding()
    comptime assert MapContract[OptionalFamily,Optional[Int],MissingMap].Compatible
    comptime assert BindContract[OptionalFamily,Optional[Int],MissingBind].Compatible
    comptime assert CombineContract[OptionalFamily,Optional[Int],MissingBinary,Next].Compatible
    comptime assert CombineContract[OptionalFamily,Optional[Int],Add,MissingThunk].Compatible
    comptime assert not MapContract[OptionalFamily,Optional[Int],MissingMap].InvocationCompatible
    comptime assert not BindContract[OptionalFamily,Optional[Int],MissingBind].InvocationCompatible
    comptime assert not CombineContract[OptionalFamily,Optional[Int],MissingBinary,Next].InvocationCompatible
    comptime assert not CombineContract[OptionalFamily,Optional[Int],Add,MissingThunk].InvocationCompatible
    comptime assert not Map2Contract[OptionalFamily,Optional[Int],Optional[Int],MissingBinary].InvocationCompatible
    comptime assert ProductContract[OptionalFamily,Optional[Int],Optional[Int]].InvocationCompatible
    assert_equal(checked_map[ListFamily](List[Int]([1,2]),Counter(0)),[2,4])
    var calls = ArcPointer(0)
    var drops = ArcPointer(0)
    assert_equal(checked_combine[OptionalFamily](Optional(3),Add(),Pending(calls,Token(drops))).value(),10)
    assert_equal(calls[],1)
    assert_equal(drops[],1)
    _ = checked_combine[OptionalFamily](Optional[Int](),Add(),Pending(calls,Token(drops)))
    assert_equal(calls[],1)
    assert_equal(drops[],2)
    var code = 0
    try: _ = checked_map[PublicMonad[OptionalFamily,1]](Optional(3),Echo())
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,702)
    try: _ = checked_bind[PublicMonad[OptionalFamily,2]](Optional(3),Present())
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,703)
    try: _ = checked_combine[PublicMonad[OptionalFamily,3]](Optional(3),Add(),Pending(calls,Token(drops)))
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,704)
    assert_equal(calls[],1)
    assert_equal(drops[],3)
    comptime R = Reader[Int]
    var deferred = checked_map[R](R.pure(3),Echo())
    assert_equal(run[R](deferred^,0),3)
    origins(List[Int]([1,2]))
