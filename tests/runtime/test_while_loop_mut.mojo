from fp.control import while_loop_mut
from fp.control import while_loop
from fp.callables import MutableUnary, Unary, OnceUnary, BorrowSignature, BorrowCallable
from fp.functions import as_unary, flow, partial
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Step(MutableUnary):
    var calls: Int
    comptime Arg = Int
    comptime Out = Int
    def call_mut(mut self, var value: Int) -> Int:
        self.calls += 1
        return value + 1

@fieldwise_init
struct Both(Unary, MutableUnary, OnceUnary):
    var calls: Int
    comptime Arg = Int
    comptime Out = Int
    def call(self, var value: Int) -> Int: return value + 1
    def call_mut(mut self, var value: Int) -> Int:
        self.calls += 1
        return value + 2
    def call_once(deinit self, var value: Int) -> Int: return 999

@fieldwise_init
struct Failing(MutableUnary):
    var visited: List[Int]
    comptime Arg = Int
    comptime Out = Int
    comptime Error = Int
    def call_mut(mut self, var value: Int) raises Int -> Int:
        self.visited.append(value)
        if value == 2: raise -2
        return value + 1

def below(value: Int) -> Bool: return value < 4
def limit(value: Int) raises Int -> Bool:
    if value == 2: raise -7
    return value < 4
def never(value: Int) raises Never -> Bool: return value < 4
def increment(var value: Int) -> Int: return value + 1
def less(bound: Int, value: Int) -> Bool: return value < bound

def generic[F: MutableUnary](mut body: F) raises F.Error -> Int where F.Arg == Int and F.Out == Int:
    return while_loop_mut(below, body, 0)
def generic_shared[F: Unary](mut body: F) raises F.Error -> Int where F.Arg == Int and F.Out == Int:
    return while_loop_mut(below, body, 0)
comptime Predicate = def(Int) thin -> Bool

@fieldwise_init
struct Append(MutableUnary):
    var calls: Int
    comptime Arg = String
    comptime Out = String
    def call_mut(mut self, var value: String) -> String:
        self.calls += 1
        return value + "x"

def short(value: String) -> Bool: return value.byte_length() < 4
def short_never(value: String) raises Never -> Bool: return value.byte_length() < 4
def short_error(value: String) raises Int -> Bool:
    if value.byte_length() == 2: raise -8
    return value.byte_length() < 4

def memory() raises:
    var body = Append(0)
    assert_equal(while_loop_mut(short, body, String()), "xxxx")
    assert_equal(while_loop_mut(short_never, body, String()), "xxxx")
    var pointer: def(String) raises Int thin -> Bool = short_error
    var observed = 0
    try: _ = while_loop_mut(pointer, body, String())
    except error: observed = error
    assert_equal(observed, -8)
    assert_equal(body.calls, 10)

def generic_predicate[P: BorrowCallable, F: MutableUnary](predicate: P, mut body: F) raises F.Error -> Int where P.Payload == Int and P.Result == Bool and P.Failure == Never and F.Arg == Int and F.Out == Int:
    return while_loop_mut[E=F.Error](predicate, body, 0)

def generic_same_error[P: BorrowCallable, F: MutableUnary](predicate: P, mut body: F) raises F.Error -> Int where P.Payload == Int and P.Result == Bool and P.Failure == F.Error and F.Arg == Int and F.Out == Int:
    return while_loop_mut[E=F.Error](predicate, body, 0)

def main() raises:
    memory()
    var step = Step(0)
    assert_equal(while_loop_mut(below, step, 0), 4)
    assert_equal(step.calls, 4)
    assert_equal(while_loop_mut(below, step, 4), 4)
    assert_equal(step.calls, 4)
    assert_equal(generic(step), 4)
    var stored: Predicate = below
    assert_equal(while_loop_mut(BorrowSignature[Int, Bool].capture(stored), step, 0), 4)
    assert_equal(while_loop_mut(never, step, 0), 4)
    var bound = 5
    def captured(value: Int) {bound} -> Bool: return value < bound
    var predicate = BorrowSignature[Int, Bool].capture(captured)
    assert_equal(while_loop_mut(predicate, step, 0), 5)
    assert_equal(while_loop_mut(partial(less, 3), step, 0), 3)
    assert_equal(step.calls, 24)
    var pointer_body = Step(0)
    var direct: def(Int) thin -> Bool = below
    assert_equal(while_loop_mut(direct, pointer_body, 0), 4)
    assert_equal(generic_predicate(predicate, pointer_body), 5)
    assert_equal(pointer_body.calls, 9)
    var dual = Both(0)
    assert_equal(while_loop(BorrowSignature[Int, Bool].capture(below), dual, 0), 4)
    assert_equal(dual.calls, 0)
    assert_equal(while_loop_mut(below, dual, 0), 4)
    assert_equal(generic_shared(dual), 4)
    assert_equal(generic(dual), 4)
    assert_equal(dual.calls, 6)
    var shared = as_unary(increment)
    assert_equal(while_loop_mut(below, shared, 0), 4)
    var composed = flow(Step(0), increment)
    assert_equal(while_loop_mut(below, composed, 0), 4)
    assert_equal(composed.call_mut(0), 2)
    var checks = ArcPointer(0)
    def counted(value: Int) {checks} -> Bool:
        checks[] += 1
        return value < 100000
    var large = Step(0)
    assert_equal(while_loop_mut(BorrowSignature[Int, Bool].capture(counted), large, 0), 100000)
    assert_equal(large.calls, 100000)
    assert_equal(checks[], 100001)
    var failed = Failing(List[Int]())
    var observed = 0
    try: _ = while_loop_mut(below, failed, 0)
    except error:
        comptime assert type_of(error) == Int
        observed = error
    assert_equal(observed, -2)
    assert_equal(failed.visited, [0, 1, 2])
    assert_equal(while_loop_mut(below, failed, 3), 4)
    assert_equal(failed.visited, [0, 1, 2, 3])
    var generic_fail = Failing(List[Int]())
    try: _ = generic(generic_fail)
    except error: observed = error
    assert_equal(observed, -2)
    assert_equal(generic_fail.visited, [0, 1, 2])
    var stopped = Step(0)
    try: _ = while_loop_mut(limit, stopped, 0)
    except error:
        comptime assert type_of(error) == Int
        observed = error
    assert_equal(observed, -7)
    assert_equal(stopped.calls, 2)
    var same_error = Failing(List[Int]())
    try: _ = generic_same_error(BorrowSignature[Int, Bool, Int].capture(limit), same_error)
    except error: observed = error
    assert_equal(observed, -7)
    assert_equal(same_error.visited, [0, 1])
