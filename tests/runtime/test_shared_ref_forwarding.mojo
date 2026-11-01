"""Public SharedRef describes shared callbacks in immediate and deferred wrappers."""
from fp.callables import SharedRef,Thunk,shared_ref
from fp.algebra import Monad, OptionalFamily
from fp.algebra.contracts import BeforeContract, FollowedByContract
from fp.effects import Reader,run
from fp.functions import pipeline
from test_context_sequencing_contracts import Create
from std.memory import ArcPointer
from std.testing import assert_equal

def keep[I:Monad,V:Movable & Deinitable,F:Thunk,o:ImmOrigin](var source:V,ref[o] factory:F) raises BeforeContract[I,V,SharedRef[F,o]].Error -> BeforeContract[I,V,SharedRef[F,o]].Out where BeforeContract[I,V,SharedRef[F,o]].InvocationCompatible:
    return pipeline[I](source^).before(shared_ref(factory)).get()

def follow[I:Monad,V:Movable & Deinitable,F:Thunk,o:ImmOrigin](var source:V,ref[o] factory:F) raises FollowedByContract[I,V,SharedRef[F,o]].Error -> FollowedByContract[I,V,SharedRef[F,o]].Out where FollowedByContract[I,V,SharedRef[F,o]].InvocationCompatible:
    return pipeline[I](source^).followed_by(shared_ref(factory)).get()

def main() raises:
    var calls=ArcPointer(0)
    var immediate=Create[OptionalFamily](calls)
    assert_equal(keep[OptionalFamily](Optional(3),immediate).value(),3)
    assert_equal(follow[OptionalFamily](Optional(3),immediate).value(),7)
    assert_equal(calls[],2)
    comptime R=Reader[Int]
    var deferred=Create[R](calls)
    var pending=keep[R](R.pure(3),deferred)
    assert_equal(calls[],2)
    assert_equal(run[R](pending^,0),3)
    assert_equal(calls[],3)
    var next=follow[R](R.pure(3),deferred)
    assert_equal(run[R](next^,0),7)
    assert_equal(calls[],4)
