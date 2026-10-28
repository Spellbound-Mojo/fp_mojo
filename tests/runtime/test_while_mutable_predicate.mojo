"""Mutable loop predicates preserve receiver selection and retained state."""
from fp.callables import BorrowCallContract, UnaryContract, BorrowCallable, BorrowMutableCallable, BorrowOnceCallable, MutableUnary, mut_ref
from fp.control import while_loop_mut
from std.testing import assert_equal

@fieldwise_init
struct Predicate(BorrowMutableCallable):
    comptime Payload = Int
    comptime Result = Bool
    var calls: Int
    def invoke_mut(mut self, ref value: Int) -> Bool:
        self.calls += 1
        return self.calls < 4

@fieldwise_init
struct Body(MutableUnary):
    comptime Arg = Int
    comptime Out = Int
    var calls: Int
    def call_mut(mut self, var value: Int) -> Int:
        self.calls += 1
        return value + 2

@fieldwise_init
struct Modes(BorrowCallable, BorrowMutableCallable, BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = Bool
    var calls: Int
    def invoke(self, ref value: Int) -> Bool: return value < 4
    def invoke_mut(mut self, ref value: Int) -> Bool:
        self.calls += 1
        return self.calls < 4
    def invoke_once(deinit self, ref value: Int) -> Bool: return False

def below_four(value: Int) -> Bool: return value < 4

@fieldwise_init
struct ThrowingPredicate(BorrowMutableCallable):
    comptime Payload = Int
    comptime Result = Bool
    comptime Failure = Int
    var calls: Int
    var fail_at: Int
    def invoke_mut(mut self, ref value: Int) raises Int -> Bool:
        self.calls += 1
        if self.calls == self.fail_at: raise -7
        return value < 4

@fieldwise_init
struct ThrowingBody(MutableUnary):
    comptime Arg = Int
    comptime Out = Int
    comptime Error = Int
    var calls: Int
    var fail_at: Int
    def call_mut(mut self, var value: Int) raises Int -> Int:
        self.calls += 1
        if self.calls == self.fail_at: raise -8
        return value + 1

def forward[P: BorrowCallContract & Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var predicate: P, mut body: F, var initial: F.Arg) raises F.Error -> F.Arg where P.Payload == F.Arg and P.Result == Bool and P.Failure == F.Error and F.Out == F.Arg:
    return while_loop_mut[E=F.Error](predicate^,body,initial^)

def forward_pure[P: BorrowCallContract & Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var predicate: P, mut body: F, var initial: F.Arg) raises F.Error -> F.Arg where P.Payload == F.Arg and P.Result == Bool and P.Failure == Never and F.Out == F.Arg:
    return while_loop_mut[E=F.Error](predicate^,body,initial^)

def main() raises:
    var predicate = Predicate(0)
    var body = Body(0)
    assert_equal(while_loop_mut(mut_ref(predicate),body,0),6)
    assert_equal(predicate.calls,4)
    assert_equal(body.calls,3)
    assert_equal(while_loop_mut(Predicate(0),body,0),6)
    assert_equal(body.calls,6)
    var shared = Modes(0)
    assert_equal(while_loop_mut(shared,body,0),4)
    assert_equal(shared.calls,0)
    assert_equal(while_loop_mut(shared^,body,0),6)
    assert_equal(while_loop_mut(Modes(0),body,0),6)
    assert_equal(while_loop_mut(below_four,body,0),4)

    for scenario in range(4):
        var check = ThrowingPredicate(0,2 if scenario == 1 else 0)
        var advance = ThrowingBody(0,2 if scenario == 2 else 0)
        var result = -1
        var observed = 0
        try:
            result = forward(mut_ref(check),advance,4 if scenario == 3 else 0)
        except error:
            comptime assert type_of(error) == Int
            observed = error
        assert_equal(observed,-7 if scenario == 1 else -8 if scenario == 2 else 0)
        assert_equal(result,-1 if scenario == 1 or scenario == 2 else 4)
        assert_equal(check.calls,5 if scenario == 0 else 1 if scenario == 3 else 2)
        assert_equal(advance.calls,4 if scenario == 0 else 1 if scenario == 1 else 2 if scenario == 2 else 0)
    var generic_body = ThrowingBody(0,0)
    var generic_value: Int
    try:
        generic_value = forward_pure(Predicate(0),generic_body,0)
    except:
        raise Error("unexpected generic loop failure")
    assert_equal(generic_value,3)
    assert_equal(generic_body.calls,3)
