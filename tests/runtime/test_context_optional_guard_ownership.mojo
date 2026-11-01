"""Optional repeated branches preserve receiver state, cleanup and native origins."""
from std.memory import ArcPointer
from std.builtin.rebind import rebind_var
from std.testing import assert_equal
from fp.algebra import IdentityFamily
from fp.algebra._branches import _OptionalGuard
from fp.callables import UnaryContract, Unary, MutableUnary
from fp.callables.invoke import RepeatableUnary
from test_context_failure_forwarding_ownership import Owner

@fieldwise_init
struct Shared(Unary):
    var owner: Owner
    var calls: ArcPointer[Int]
    var fail_on: Int
    comptime Arg = Owner
    comptime Out = Optional[Owner]
    comptime Error = Int
    def call(self, var value: Owner) raises Int -> Self.Out:
        self.calls[] += 1
        self.owner.trace[] += "s" + String(self.calls[])
        if self.calls[] == self.fail_on: raise 83
        return Optional(value^)

@fieldwise_init
struct Dual(Unary,MutableUnary):
    var owner: Owner
    var calls: ArcPointer[Int]
    var fail_on: Int
    var count: Int
    comptime Arg = Owner
    comptime Out = Optional[Owner]
    comptime Error = Int
    def call(self, var value: Owner) raises Int -> Self.Out:
        self.owner.trace[] += "unexpected-shared"
        return Optional(value^)
    def call_mut(mut self, var value: Owner) raises Int -> Self.Out:
        self.count += 1
        self.calls[] = self.count
        self.owner.trace[] += "m" + String(self.count)
        if self.count == self.fail_on: raise 83
        return Optional(value^)

def exercise[F: UnaryContract & Movable & Deinitable](var f: F, trace: ArcPointer[String], calls: ArcPointer[Int]) raises -> String where F.Arg == Owner and F.Out == Optional[Owner] and F.Error == Int and RepeatableUnary[F]:
    comptime Guard = _OptionalGuard[IdentityFamily,F]
    comptime assert Guard.Arg == Optional[Owner] and Guard.Out == Optional[Owner]
    var guard = Guard(f^)
    var returned = String()
    for index in range(4):
        var value = Optional[Owner]()
        if index % 2: value = Owner(index + 1,trace)
        try:
            var result = rebind_var[Optional[Owner]](guard.call_mut(rebind_var[Guard.Arg](value^)))
            if result: returned += String(result.value().id)
            _ = result^
        except error:
            comptime assert type_of(error) == Int
            trace[] += "c" + String(rebind_var[Int](error^))
    assert_equal(calls[],2)
    _ = guard^
    return returned + ":" + trace[]

@fieldwise_init
struct Borrowed[v: ImmOrigin,e: ImmOrigin](MutableUnary):
    var value: Pointer[Int,Self.v]
    var failure: Pointer[Int,Self.e]
    comptime Arg = Bool
    comptime Out = Optional[Pointer[Int,Self.v]]
    comptime Error = Pointer[Int,Self.e]
    def call_mut(mut self, var success: Bool) raises Self.Error -> Self.Out:
        if not success: raise self.failure
        return Optional(self.value)

def origins[v: ImmOrigin,e: ImmOrigin](ref[v] value: Int,ref[e] failure: Int) raises:
    var guard = _OptionalGuard[IdentityFamily,Borrowed[v,e]](Borrowed(Pointer(to=value),Pointer(to=failure)))
    var empty = False
    var returned = False
    var caught = False
    try:
        var absent = guard.call_mut(Optional[Bool]())
        empty = not absent
        var result = guard.call_mut(Optional(True))
        comptime assert type_of(result) == Optional[Pointer[Int,v]]
        returned = result.value() == Pointer(to=value)
        _ = guard.call_mut(Optional(False))
    except error:
        comptime assert type_of(error) == Pointer[Int,e]
        caught = error == Pointer(to=failure)
    assert_equal(empty,True)
    assert_equal(returned,True)
    assert_equal(caught,True)

def main() raises:
    for fail_on in range(3):
        var trace = ArcPointer(String())
        var calls = ArcPointer(0)
        var expected = "24:s12s249" if fail_on == 0 else "4:s12c83s249" if fail_on == 1 else "2:s12s24c839"
        assert_equal(exercise(Shared(Owner(9,trace),calls,fail_on),trace,calls),expected)
        trace = ArcPointer(String())
        calls = ArcPointer(0)
        expected = "24:m12m249" if fail_on == 0 else "4:m12c83m249" if fail_on == 1 else "2:m12m24c839"
        assert_equal(exercise(Dual(Owner(9,trace),calls,fail_on,0),trace,calls),expected)
    var value = 3
    var failure = 7
    origins(value,failure)
