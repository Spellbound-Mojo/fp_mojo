"""Generic forwards and independently borrowed outputs retain exact public types."""
from fp.callables import ThunkContract, UnaryContract, OnceThunk, BorrowCallable
from fp.effects import ReaderAction
from fp.effects.resources import resource, ResourceContract
from fp.effects.io import IOContract, delay, run_io
from std.testing import assert_equal

def construct_scope[A: ThunkContract & Movable & Deinitable, R: UnaryContract & Movable & Deinitable, //, E: Movable & Deinitable](var acquire: A, var release: R) -> ResourceContract[A, R, E].Out where ResourceContract[A, R, E].Compatible:
    return resource[E](acquire^, release^)

def execute_io[P: ReaderAction](var program: P) -> IOContract[P].Out where IOContract[P].Compatible:
    return run_io(program^)

@fieldwise_init
struct ScopeContractAcquire(OnceThunk):
    comptime Out = Int
    def call_once(deinit self) -> Int: return 1

def scope_contract_release(var value: Int): pass

@fieldwise_init
struct ScopeIndependentProjection[o: ImmOrigin](BorrowCallable):
    var owner: Pointer[List[Int], Self.o]
    comptime Payload = Int
    comptime Result = Span[Int, Self.o]
    def invoke(self, ref value: Int) -> Self.Result: return Span(self.owner[])

@fieldwise_init
struct IOIndependentProjection[o: ImmOrigin](OnceThunk):
    var owner: Pointer[List[Int], Self.o]
    comptime Out = Span[Int, Self.o]
    def call_once(deinit self) -> Self.Out: return Span(self.owner[])

def main() raises:
    from fp.callables import as_unary
    var owner = List[Int]([7, 8])
    var scope = construct_scope[Error](ScopeContractAcquire(), as_unary(scope_contract_release))
    var result = scope^.use(ScopeIndependentProjection(Pointer(to=owner)))
    var span = result^._take_ok()
    assert_equal(span[1], 8)
    var outcome = execute_io(delay[Error](IOIndependentProjection(Pointer(to=owner))))
    var success = outcome.take()
    var io_span = success^._take_ok()
    assert_equal(io_span[0], 7)
