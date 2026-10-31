"""Generic sequencing uses public contracts with exact family semantics."""
from fp.algebra import Applicative, Monad, ListFamily, OptionalFamily
from fp.algebra.contracts import FlatTapContract, FlatPairWithContract, BeforeContract, FollowedByContract
from fp.callables import BorrowCallContract, BorrowCallable, BorrowOnceCallable, ThunkContract, Thunk, MutableThunk, OnceThunk, UnaryContract, BinaryContract
from fp.functions import Pipeline, pipeline, Identity
from fp.effects import Reader, run
from std.memory import ArcPointer
from std.builtin.rebind import downcast, rebind_var
from std.testing import assert_equal
from test_algebra_third_party import Cell, CellFamily


def tapped[I: Monad, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var value: V, var callback: C) raises FlatTapContract[I,V,C].Error -> Pipeline[FlatTapContract[I,V,C].Family, FlatTapContract[I,V,C].Out] where FlatTapContract[I,V,C].Compatible:
    return pipeline[I](value^).flat_tap(callback^)


def paired[I: Monad, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var value: V, var callback: C) raises FlatPairWithContract[I,V,C].Error -> Pipeline[FlatPairWithContract[I,V,C].Family, FlatPairWithContract[I,V,C].Out] where FlatPairWithContract[I,V,C].Compatible:
    return pipeline[I](value^).flat_pair_with(callback^)


def kept[I: Monad, V: Movable & Deinitable, F: ThunkContract & Movable & Deinitable](var value: V, var factory: F) raises BeforeContract[I,V,F].Error -> Pipeline[BeforeContract[I,V,F].Family, BeforeContract[I,V,F].Out] where BeforeContract[I,V,F].Compatible:
    return pipeline[I](value^).before(factory^)


def followed[I: Monad, V: Movable & Deinitable, F: ThunkContract & Movable & Deinitable](var value: V, var factory: F) raises FollowedByContract[I,V,F].Error -> Pipeline[FollowedByContract[I,V,F].Family, FollowedByContract[I,V,F].Out] where FollowedByContract[I,V,F].Compatible:
    return pipeline[I](value^).followed_by(factory^)


# Old expanded proofs can call the new wrappers and vice versa. Private names
# appear only here to qualify pre-existing generic signatures, not in clients.
from fp.algebra._sequencing import _EffectRetain
from fp.callables._transforms import _IgnoreInput, _BorrowedUnary

def expanded[I: Monad, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var value: V, var callback: C) raises FlatTapContract[I,V,C].Error -> FlatTapContract[I,V,C].Out where C.Payload == I.Element[V] and I.CarrierCompatible[C.Result] and I.BindCompatible[V, _EffectRetain[I.Element[V], I, C]]:
    return tapped[I](value^, callback^).get()


def forwarded[I: Monad, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var value: V, var callback: C) raises FlatTapContract[I,V,C].Error -> FlatTapContract[I,V,C].Out where FlatTapContract[I,V,C].Compatible:
    return expanded[I](value^, callback^)


def expanded_pair[I: Monad, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var value: V, var callback: C) raises FlatPairWithContract[I,V,C].Error -> FlatPairWithContract[I,V,C].Out where C.Payload == I.Element[V] and I.CarrierCompatible[C.Result] and I.BindCompatible[V, _EffectRetain[I.Element[V], I, C, False, True]]:
    return paired[I](value^, callback^).get()


def expanded_before[I: Monad, V: Movable & Deinitable, F: ThunkContract & Movable & Deinitable](var value: V, var factory: F) raises BeforeContract[I,V,F].Error -> BeforeContract[I,V,F].Out where I.CarrierCompatible[F.Out] and I.BindCompatible[V, _EffectRetain[I.Element[V], I, _IgnoreInput[I.Element[V], F]]]:
    return kept[I](value^, factory^).get()


def expanded_followed[I: Monad, V: Movable & Deinitable, F: ThunkContract & Movable & Deinitable](var value: V, var factory: F) raises FollowedByContract[I,V,F].Error -> FollowedByContract[I,V,F].Out where I.CarrierCompatible[F.Out] and I.BindCompatible[V, _BorrowedUnary[I.Element[V], _IgnoreInput[I.Element[V], F]]]:
    return followed[I](value^, factory^).get()


# Pipeline.before admits BeforeContract.Compatible or the expanded components
# above; Piped's CarrierCompatible-only legacy proof is not ported.


@fieldwise_init
struct Project[I: Monad](BorrowCallable):
    var calls: ArcPointer[Int]
    comptime Payload = Int
    comptime Result = Self.I.Pure[Int]
    def invoke(self, ref payload: Int) -> Self.Result:
        self.calls[] += 1
        return Self.I.pure(payload + 10)


@fieldwise_init
struct Create[I: Monad](Thunk):
    var calls: ArcPointer[Int]
    comptime Out = Self.I.Pure[Int]
    def call(self) -> Self.Out:
        self.calls[] += 1
        return Self.I.pure(7)


@fieldwise_init
struct Branches(MutableThunk):
    var calls: Int
    comptime Out = List[Int]
    def call_mut(mut self) -> Self.Out:
        self.calls += 1
        return List[Int]([self.calls, self.calls + 10])


@fieldwise_init
struct Raised[I: Monad](Thunk):
    comptime Out = Self.I.Pure[Int]
    comptime Error = Int
    def call(self) raises Int -> Self.Out: raise 713


@fieldwise_init
struct Token(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct OwnedFactory[failed: Bool](OnceThunk):
    var capture: Token
    var calls: ArcPointer[Int]
    comptime Out = Optional[Int]
    comptime Error = Int if Self.failed else Never
    def call_once(deinit self) raises Self.Error -> Self.Out:
        self.calls[] += 1
        comptime if Self.failed:
            comptime assert Self.Error == Int
            raise rebind_var[Self.Error](Int(717))
        else: return Optional(self.capture.value)


@fieldwise_init
struct OwnedProjection(BorrowOnceCallable):
    var capture: Token
    comptime Payload = Token
    comptime Result = Optional[Token]
    def invoke_once(deinit self, ref payload: Token) -> Self.Result:
        return Optional(self.capture^)


@fieldwise_init
struct Echo[V: Copyable & Deinitable](BorrowCallable):
    comptime Payload = Self.V
    comptime Result = Optional[Self.V]
    def invoke(self, ref payload: Self.V) -> Self.Result: return Optional(payload.copy())


def owned[absent: Bool]() raises:
    var drops = ArcPointer(0)
    var calls = ArcPointer(0)
    var source = Optional[Token]()
    comptime if not absent: source = Optional(Token(5, drops))
    var retained = kept[OptionalFamily](source^, OwnedFactory[False](Token(7,drops),calls)).get()
    assert_equal(calls[], 0 if absent else 1)
    assert_equal(drops[], 1)
    comptime if not absent: assert_equal(retained.value().value, 5)
    _ = retained^
    assert_equal(drops[], 1 if absent else 2)


def owned_failure() raises:
    var drops = ArcPointer(0)
    var calls = ArcPointer(0)
    var code = 0
    try: _ = kept[OptionalFamily](Optional(Token(5,drops)), OwnedFactory[True](Token(7,drops),calls)).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 717)
    assert_equal(calls[], 1)
    assert_equal(drops[], 2)
    var pair = paired[OptionalFamily](Optional(Token(5,drops)), OwnedProjection(Token(7,drops))).get()
    assert_equal(pair.value()[0].value, 5)
    assert_equal(pair.value()[1].value, 7)
    _ = pair^
    assert_equal(drops[], 4)
    assert_equal(followed[OptionalFamily](Optional(Token(5,drops)), OwnedFactory[False](Token(7,drops),calls)).get().value(), 7)
    assert_equal(drops[], 6)


def origins(owner: List[Int]) raises:
    comptime View = type_of(Span(owner))
    var pair = paired[OptionalFamily](Optional(Span(owner)), Echo[View]()).get()
    assert_equal(pair.value()[0].unsafe_ptr() == Span(owner).unsafe_ptr(), True)
    assert_equal(pair.value()[1].unsafe_ptr() == Span(owner).unsafe_ptr(), True)


struct ConstructionFailure(Monad):
    comptime Base = OptionalFamily
    comptime Element[V: Movable & Deinitable] = Self.Base.Element[V]
    comptime Pure[A: Movable & Deinitable] = Self.Base.Pure[A]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.Mapped[V,F]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.MapError[V,F]
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Self.Base.Combined[V,F,R]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Self.Base.CombineError[V,F,R]
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Self.Base.Bound[V,F]
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Int
    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]: return Self.Base.pure(value^)
    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises Self.MapError[V,F] -> Self.Mapped[V,F]: return Self.Base.map(f^,value^)
    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var f: F, var left: V, var right: R) raises Self.CombineError[V,F,R] -> Self.Combined[V,F,R]: return Self.Base.map2_lazy(f^,left^,right^)
    @staticmethod
    def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var source: V) raises Int -> Self.Bound[V,F]: raise 719


def main() raises:
    conditional_witness()
    var calls = ArcPointer(0)
    assert_equal(forwarded[ListFamily](List[Int]([1,2]), Project[ListFamily](calls)), [1,2])
    assert_equal(expanded_pair[ListFamily](List[Int]([1,2]), Project[ListFamily](calls)), [(1,11),(2,12)])
    assert_equal(expanded_before[ListFamily](List[Int]([1,2]), Branches(0)), [1,1,2,2])
    assert_equal(expanded_followed[ListFamily](List[Int]([1,2]), Branches(0)), [1,11,2,12])
    var selected = tapped[CellFamily](Cell(3), Project[CellFamily](calls))
    comptime assert type_of(selected).I == CellFamily
    assert_equal(selected^.get().take(), 3)
    comptime R = Reader[Int]
    calls[] = 0
    var deferred = paired[R](R.pure(3), Project[R](calls)).get()
    assert_equal(calls[], 0)
    assert_equal(run[R](deferred^, 0), (3,13))
    assert_equal(calls[], 1)
    var continued = followed[R](R.pure(3), Create[R](calls)).map(Identity[Int]()).get()
    assert_equal(calls[], 1)
    assert_equal(run[R](continued^, 0), 7)
    assert_equal(calls[], 2)
    comptime assert BeforeContract[R, R.Pure[Int], Raised[R]].Error == Never
    comptime assert BeforeContract[OptionalFamily, Optional[Int], Raised[OptionalFamily]].Error == Int
    var pending = kept[R](R.pure(3), Raised[R]()).get()
    var code = 0
    try: _ = run[R](pending^, 0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,713)
    calls[] = 0
    try: _ = kept[ConstructionFailure](Optional(3), Create[ConstructionFailure](calls)).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,719)
    assert_equal(calls[],0)
    owned[False]()
    owned[True]()
    owned_failure()
    origins(List[Int]([1,2]))


# Conditional capabilities retain the exact public Monad witness in both
# metadata and invocation, including deferred associated result/error types.
def conditional_tapped[I: Applicative, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var value: V, var callback: C) raises FlatTapContract[downcast[I,Monad],V,C].Error -> Pipeline[FlatTapContract[downcast[I,Monad],V,C].Family, FlatTapContract[downcast[I,Monad],V,C].Out] where conforms_to(I, Monad) and FlatTapContract[downcast[I,Monad],V,C].Compatible:
    return pipeline[downcast[I,Monad]](value^).flat_tap(callback^)


def conditional_paired[I: Applicative, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var value: V, var callback: C) raises FlatPairWithContract[downcast[I,Monad],V,C].Error -> Pipeline[FlatPairWithContract[downcast[I,Monad],V,C].Family, FlatPairWithContract[downcast[I,Monad],V,C].Out] where conforms_to(I, Monad) and FlatPairWithContract[downcast[I,Monad],V,C].Compatible:
    return pipeline[downcast[I,Monad]](value^).flat_pair_with(callback^)


def conditional_kept[I: Applicative, V: Movable & Deinitable, F: ThunkContract & Movable & Deinitable](var value: V, var factory: F) raises BeforeContract[downcast[I,Monad],V,F].Error -> Pipeline[BeforeContract[downcast[I,Monad],V,F].Family, BeforeContract[downcast[I,Monad],V,F].Out] where conforms_to(I, Monad) and BeforeContract[downcast[I,Monad],V,F].Compatible:
    return pipeline[downcast[I,Monad]](value^).before(factory^)


def conditional_followed[I: Applicative, V: Movable & Deinitable, F: ThunkContract & Movable & Deinitable](var value: V, var factory: F) raises FollowedByContract[downcast[I,Monad],V,F].Error -> Pipeline[FollowedByContract[downcast[I,Monad],V,F].Family, FollowedByContract[downcast[I,Monad],V,F].Out] where conforms_to(I, Monad) and FollowedByContract[downcast[I,Monad],V,F].Compatible:
    return pipeline[downcast[I,Monad]](value^).followed_by(factory^)


def conditional_witness() raises:
    var calls = ArcPointer(0)
    comptime O = OptionalFamily
    assert_equal(conditional_tapped[O](O.pure(3), Project[O](calls)).get().value(), 3)
    assert_equal(conditional_paired[O](O.pure(3), Project[O](calls)).get().value(), (3,13))
    assert_equal(conditional_kept[O](O.pure(3), Create[O](calls)).get().value(), 3)
    assert_equal(conditional_followed[O](O.pure(3), Create[O](calls)).get().value(), 7)
    comptime R = Reader[Int]
    var a = conditional_tapped[R](R.pure(3), Project[R](calls)).get()
    var b = conditional_paired[R](R.pure(3), Project[R](calls)).get()
    var c = conditional_kept[R](R.pure(3), Create[R](calls)).get()
    var d = conditional_followed[R](R.pure(3), Create[R](calls)).get()
    assert_equal(run[R](a^, 0), 3)
    assert_equal(run[R](b^, 0), (3,13))
    assert_equal(run[R](c^, 0), 3)
    assert_equal(run[R](d^, 0), 7)
