"""Experimental family and error selection before native callback inference."""
from std.builtin.rebind import downcast
from fp.algebra.protocols import Functor, Filterable
from fp.algebra.instances import ListFamily, OptionalFamily, ResultFamily
from fp.algebra.operations import _map_native, _ErrorProbe
from fp.algebra.filtering import _filter_native
from fp.algebra._admission import _MapCompatible
from fp.callables.native import _NativeUnaryRef, _NativeBorrowRef, _NativeBorrow
from fp.callables.protocols import UnaryContract, BorrowCallable, OnceThunk
from fp.data._result import Result, _attempt_core, _attempt_native, _attempt_native_pure, attempt_once

comptime _Filtering[I: Functor] = downcast[I, Filterable]

@fieldwise_init
struct Pipeline[I: Functor, V: Movable & Deinitable, E: Movable & Deinitable = Never](Movable):
    var value: Self.V

    def raising[X: Movable & Deinitable](deinit self) -> Pipeline[Self.I, Self.V, X]:
        return Pipeline[Self.I, Self.V, X](self.value^)

    def get(deinit self) -> Self.V:
        return self.value^

    def map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //,
            F: def(var A) -> R](deinit self, ref[o] function: F
    ) raises Self.I.MapError[Self.V, _ErrorProbe[A, R, Never]] -> Pipeline[Self.I, Self.I.Mapped[Self.V, _NativeUnaryRef[A, R, Never, F, False, o]], Self.E] where Self.I.Element[Self.V] == A and _MapCompatible[Self.I, Self.V, _ErrorProbe[A, R, Never]]:
        return Pipeline[Self.I, Self.I.Mapped[Self.V, _NativeUnaryRef[A, R, Never, F, False, o]], Self.E](_map_native[Self.V, A, R, Never, Self.I, F, False, o](function, self.value^))

    def map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //,
            F: def(var A) raises Self.E -> R](deinit self, ref[o] function: F
    ) raises Self.I.MapError[Self.V, _ErrorProbe[A, R, Self.E]] -> Pipeline[Self.I, Self.I.Mapped[Self.V, _NativeUnaryRef[A, R, Self.E, F, True, o]], Self.E] where Self.I.Element[Self.V] == A and _MapCompatible[Self.I, Self.V, _ErrorProbe[A, R, Self.E]]:
        return Pipeline[Self.I, Self.I.Mapped[Self.V, _NativeUnaryRef[A, R, Self.E, F, True, o]], Self.E](_map_native[Self.V, A, R, Self.E, Self.I, F, True, o](function, self.value^))

    def map[F: UnaryContract & Movable & Deinitable](deinit self, var function: F
    ) raises Self.I.MapError[Self.V, F] -> Pipeline[Self.I, Self.I.Mapped[Self.V, F], Self.E] where Self.I.Element[Self.V] == F.Arg and _MapCompatible[Self.I, Self.V, F]:
        return Pipeline[Self.I, Self.I.Mapped[Self.V, F], Self.E](Self.I.map(function^, self.value^))

    def filter[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //,
               F: def(P) -> R](deinit self, ref[o] predicate: F
    ) raises _Filtering[Self.I].FilterError[Self.V, _NativeBorrowRef[P, Bool, Never, F, False, o]] -> Pipeline[Self.I, _Filtering[Self.I].Filtered[Self.V, _NativeBorrowRef[P, Bool, Never, F, False, o]], Self.E] where conforms_to(Self.I, Filterable) and Self.I.Element[Self.V] == P and R == Bool:
        return Pipeline[Self.I, _Filtering[Self.I].Filtered[Self.V, _NativeBorrowRef[P, Bool, Never, F, False, o]], Self.E](_filter_native[Self.V, P, Never, _Filtering[Self.I], F, False, o](predicate, self.value^))

    def filter[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //,
               F: def(P) raises Self.E -> R](deinit self, ref[o] predicate: F
    ) raises _Filtering[Self.I].FilterError[Self.V, _NativeBorrowRef[P, Bool, Self.E, F, True, o]] -> Pipeline[Self.I, _Filtering[Self.I].Filtered[Self.V, _NativeBorrowRef[P, Bool, Self.E, F, True, o]], Self.E] where conforms_to(Self.I, Filterable) and Self.I.Element[Self.V] == P and R == Bool:
        return Pipeline[Self.I, _Filtering[Self.I].Filtered[Self.V, _NativeBorrowRef[P, Bool, Self.E, F, True, o]], Self.E](_filter_native[Self.V, P, Self.E, _Filtering[Self.I], F, True, o](predicate, self.value^))

    def filter[P: AnyType, R: Movable & Deinitable, //](deinit self, predicate: def(P) raises Never thin -> R
    ) raises _Filtering[Self.I].FilterError[Self.V, _NativeBorrow[P, R, Never, def(P) raises Never thin -> R, True]] -> Pipeline[Self.I, _Filtering[Self.I].Filtered[Self.V, _NativeBorrow[P, R, Never, def(P) raises Never thin -> R, True]], Self.E] where conforms_to(Self.I, Filterable) and Self.I.Element[Self.V] == P and R == Bool:
        comptime C = _NativeBorrow[P, R, Never, def(P) raises Never thin -> R, True]
        return Pipeline[Self.I, _Filtering[Self.I].Filtered[Self.V, C], Self.E](_Filtering[Self.I].filter(C(predicate), self.value^))

    def filter[F: BorrowCallable](deinit self, var predicate: F
    ) raises _Filtering[Self.I].FilterError[Self.V, F] -> Pipeline[Self.I, _Filtering[Self.I].Filtered[Self.V, F], Self.E] where conforms_to(Self.I, Filterable) and Self.I.Element[Self.V] == F.Payload and F.Result == Bool:
        return Pipeline[Self.I, _Filtering[Self.I].Filtered[Self.V, F], Self.E](_Filtering[Self.I].filter(predicate^, self.value^))


def piped[T: Movable & Deinitable](var value: List[T]) -> Pipeline[ListFamily, List[T]]:
    return Pipeline[ListFamily, List[T]](value^)
def piped[T: Movable & Deinitable](var value: Optional[T]) -> Pipeline[OptionalFamily, Optional[T]]:
    return Pipeline[OptionalFamily, Optional[T]](value^)
def piped[T: Movable & Deinitable, E: Movable & Deinitable](var value: Result[T, E]) -> Pipeline[ResultFamily[E], Result[T, E]]:
    return Pipeline[ResultFamily[E], Result[T, E]](value^)
def piped[V: Movable & Deinitable, //, I: Functor](var value: V) -> Pipeline[I, V]:
    return Pipeline[I, V](value^)

struct Capture[E: Movable & Deinitable]:
    @staticmethod
    def run[R: Movable & Deinitable, o: ImmOrigin, //, F: def() -> R](ref[o] function: F) -> Result[R, Never]:
        return _attempt_core[R, Never, F, _attempt_native_pure[R, F]](function)

    @staticmethod
    def run[R: Movable & Deinitable, o: ImmOrigin, //, F: def() raises Self.E -> R](ref[o] function: F) -> Result[R, Self.E]:
        return _attempt_core[R, Self.E, F, _attempt_native[R, Self.E, F]](function)

    @staticmethod
    def run[F: OnceThunk](var function: F) -> Result[F.Out, F.Error]:
        return attempt_once(function^)


def attempt[R: Movable & Deinitable, o: ImmOrigin, //, F: def() -> R](ref[o] function: F) -> Result[R, Never]:
    return Capture[Never].run(function)

def attempt[R: Movable & Deinitable, o: ImmOrigin, //, F: def() raises Never -> R](ref[o] function: F) -> Result[R, Never]:
    return Capture[Never].run(function)

def attempt[F: OnceThunk](var function: F) -> Result[F.Out, F.Error]:
    return attempt_once(function^)
