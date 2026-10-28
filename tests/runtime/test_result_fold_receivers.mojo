"""One-call receiver selection in borrowing invocation and Result folds."""
from fp.callables import BorrowCallContract, BorrowCallable, BorrowMutableCallable, BorrowOnceCallable, UnaryContract, Unary, MutableUnary, OnceUnary, mut_ref, invoke_borrowed_once, BorrowCallCompatible
from fp.data import Result, Ok, Err
from std.testing import assert_equal

@fieldwise_init
struct Shared(BorrowCallable, Unary):
    comptime Payload = Int
    comptime Result = Int
    comptime Arg = Int
    comptime Out = Int
    var offset: Int
    def invoke(self, ref value: Int) -> Int: return value + self.offset
    def call(self, var value: Int) -> Int: return value + self.offset

@fieldwise_init
struct Mutable(BorrowMutableCallable, MutableUnary):
    comptime Payload = Int
    comptime Result = Int
    comptime Failure = Int
    comptime Arg = Int
    comptime Out = Int
    comptime Error = Int
    var calls: Int
    var fail: Bool
    def invoke_mut(mut self, ref value: Int) raises Int -> Int:
        self.calls += 1
        if self.fail: raise value
        return value + self.calls
    def call_mut(mut self, var value: Int) raises Int -> Int:
        return self.invoke_mut(value)

@fieldwise_init
struct Modes(BorrowCallable, BorrowMutableCallable, BorrowOnceCallable, Unary, MutableUnary, OnceUnary):
    comptime Payload = Int
    comptime Result = Int
    comptime Arg = Int
    comptime Out = Int
    var calls: Int
    def invoke(self, ref value: Int) -> Int: return 1
    def invoke_mut(mut self, ref value: Int) -> Int:
        self.calls += 1
        return 2
    def invoke_once(deinit self, ref value: Int) -> Int: return 3
    def call(self, var value: Int) -> Int: return 1
    def call_mut(mut self, var value: Int) -> Int:
        self.calls += 1
        return 2
    def call_once(deinit self, var value: Int) -> Int: return 3

def borrowed[F: BorrowCallContract & Movable & Deinitable, G: BorrowCallContract & Movable & Deinitable](subject: Result[Int,Int], var yes: F, var no: G) raises (G.Failure if F.Failure == Never else F.Failure) -> F.Result where F.Payload == Int and G.Payload == Int and F.Result == Int and G.Result == Int and F.Failure == Int and G.Failure == Int:
    return subject.fold_once(yes^, no^)

def owned[F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable](var subject: Result[Int,Int], var yes: F, var no: G) raises (G.Error if F.Error == Never else F.Error) -> F.Out where F.Arg == Int and G.Arg == Int and F.Out == Int and G.Out == Int and F.Error == Int and G.Error == Int:
    return subject^.fold_owned_once(yes^, no^)

def invoke_generic[E: Movable & Deinitable, H: BorrowCallContract & Movable & Deinitable, T: AnyType](ref value: T, var callback: H) raises E -> H.Result where BorrowCallCompatible[E, H, T]:
    return invoke_borrowed_once[E](value, callback^)

def main() raises:
    assert_equal(Result[Int,Int](Ok(4)).fold_once(Shared(2),Shared(100)),6)
    assert_equal(Result[Int,Int](Err(4)).fold_owned_once(Shared(100),Shared(2)),6)
    var yes = Mutable(0,False)
    var no = Mutable(0,False)
    var first: Int
    var second: Int
    try:
        first = borrowed(Result[Int,Int](Ok(4)),mut_ref(yes),mut_ref(no))
        second = owned(Result[Int,Int](Err(6)),mut_ref(yes),mut_ref(no))
    except:
        raise Error("unexpected callback failure")
    assert_equal(first,5)
    assert_equal(second,7)
    assert_equal(yes.calls,1)
    assert_equal(no.calls,1)
    assert_equal(Result[Int,Int](Ok(4)).fold_once(Modes(0),Modes(0)),3)
    assert_equal(Result[Int,Int](Err(4)).fold_owned_once(Modes(0),Modes(0)),3)
    var modes = Modes(0)
    assert_equal(Result[Int,Int](Ok(4)).fold_once(mut_ref(modes),Shared(0)),2)
    assert_equal(Result[Int,Int](Ok(4)).fold_owned_once(mut_ref(modes),Shared(0)),2)
    assert_equal(modes.calls,2)

    assert_equal(invoke_generic[Never](4, Shared(2)),6)
    assert_equal(invoke_borrowed_once[Never](4, Modes(0)),3)
    var direct = Mutable(0,False)
    var direct_value: Int
    try:
        direct_value = invoke_generic[Int](4,mut_ref(direct))
    except:
        raise Error("unexpected direct invocation failure")
    assert_equal(direct_value,5)
    assert_equal(direct.calls,1)

    direct.fail = True
    var error_value = 0
    try:
        _ = invoke_borrowed_once[Int](8, mut_ref(direct))
    except error:
        error_value = error
    assert_equal(error_value,8)
    assert_equal(direct.calls,2)

    var mixed_borrow: Int
    var mixed_owned: Int
    try:
        mixed_borrow = Result[Int,Int](Ok(4)).fold_once(Shared(2),Mutable(0,True))
        mixed_owned = Result[Int,Int](Err(4)).fold_owned_once(Mutable(0,True),Shared(2))
    except:
        raise Error("inactive failure handler was called")
    assert_equal(mixed_borrow,6)
    assert_equal(mixed_owned,6)
