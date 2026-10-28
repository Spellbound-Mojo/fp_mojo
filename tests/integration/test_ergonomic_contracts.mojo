"""Generic clients forward public contracts without naming execution adapters."""
from fp.algebra import Monad, IdentityFamily, AbsenceContract, TailRecContract, or_else_absent, tail_rec_m
from fp.effects import Project, Reader, asks, run
from fp.callables import BorrowCallContract, BorrowCallable, UnaryContract, Unary, ThunkContract, OnceThunk
from fp.data import ControlFlow, Break
from std.testing import assert_equal

def project_generic[I: Project, F: BorrowCallContract & Movable & Deinitable](var function: F
) raises I.ProjectError[F] -> I.Projected[F] where I.ProjectCompatible[F] and F.Payload == I.Input:
    return asks[I](function^)

def fallback_generic[I: Monad, V: Movable & Deinitable, F: ThunkContract & Movable & Deinitable](var fallback: F, var value: V
) raises AbsenceContract[I,V,F].Error -> AbsenceContract[I,V,F].Out where AbsenceContract[I,V,F].Compatible:
    return or_else_absent[I](fallback^,value^)

def loop_generic[I: Monad, F: UnaryContract & Movable & Deinitable](var step: F, var initial: F.Arg
) raises TailRecContract[I,F].Error -> TailRecContract[I,F].Out where TailRecContract[I,F].Compatible:
    return tail_rec_m[I](step^,initial^)

@fieldwise_init
struct GenericProjection(BorrowCallable, Copyable, Defaultable):
    comptime Payload = Int
    comptime Result = Int
    def invoke(self, ref value: Int) -> Int: return value + 1

@fieldwise_init
struct GenericBackup(OnceThunk, Defaultable):
    comptime Out = Optional[Int]
    def call_once(deinit self) -> Self.Out: return Optional(5)

@fieldwise_init
struct GenericLoop(Unary, Copyable, Defaultable):
    comptime Arg = Int
    comptime Out = ControlFlow[Int,Int]
    def call(self, var value: Int) -> Self.Out: return Break(value)

def main() raises:
    var projected = project_generic[Reader[Int]](GenericProjection())
    var environment = 3
    assert_equal(run[Reader[Int]](projected^,environment),4)
    assert_equal(fallback_generic[IdentityFamily](GenericBackup(),Optional[Int]()).value(),5)
    assert_equal(loop_generic[IdentityFamily](GenericLoop(),7),7)
