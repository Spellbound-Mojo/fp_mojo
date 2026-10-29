"""Immediate pipelines; the same planning and traversal serve stored compositions.

A stage is a plain function, a closure promoted with `as_unary`, or a `Unary`
library value such as a `Partial` or a `Composition`. Each stage's own contract
fixes its types. `piped(value).then(f)` chains stages one call at a time, with no
stage limit and no promotion.
"""
from fp.algebra.contracts import ApContract, ProductContract, Map2Contract, IfContract
from fp.algebra.contracts import AnyContract, AllContract, FindContract, FindMapContract, FoldMapContract, FoldContract
from fp.algebra._admission import _MapCompatible, _BindCompatible, _CombineCompatible, _CollectCompatible
from fp.algebra.validation import ValidationFamily, _ListErrors
from fp.algebra._sequencing import _EffectRetain
from fp.callables.native import _call_native_never, _call_native_borrow, _NativeThunkRef
from fp.algebra._adapt import _flat_map_as, _or_else_as
from fp.algebra.errors import _Recovered, _ErrorFamily, _ConditionalRecovery, _ObserveError, _ErrorObservation
from fp.algebra._outcomes import _ErrorMonad, _Ensure, _Redeem, _AttemptTap
from fp.algebra.protocols import ApplicativeError, _CALLBACK_ADMISSION
from fp.callables._transforms import _IgnoreInput, _BorrowedUnary
from fp.algebra.protocols import Semigroup
from fp.algebra._admission import _CarrierCompatible
from fp.algebra._nary import _ProductRun, _ProductTypes, _MapNTypes, _map_n_as
from fp.callables._views import _UnaryViewable, _BorrowViewable
from fp.callables._nary import (_Nary1, _RaisingNary1, _NativeNary1, _Nary2, _RaisingNary2, _NativeNary2, _Nary3, _RaisingNary3, _NativeNary3, _Nary4, _RaisingNary4, _NativeNary4, _Nary5, _RaisingNary5, _NativeNary5, _Nary6, _RaisingNary6, _NativeNary6, _Nary7, _RaisingNary7, _NativeNary7, _Nary8, _RaisingNary8, _NativeNary8)

from fp.algebra._effect_combinators import _AllLive, _BoolLive, _PredicateStep, _EffectFold, _fold_effect, _IfEffect, _if_effect
from fp.algebra.instances import ListFamily, OptionalFamily, ResultFamily, _InferredApplicative
from fp.algebra.operations import _EntryError, _InferError
from fp.data._result import _ResultType
from fp.iteration._advance import _Source

from fp.algebra.instances import _ListElement

from fp.algebra._traversal import _FlattenAfter, _CompactAfter, _traverse_then, _Discard, _TraverseTap, _traverse_void, _traverse_as, _EffectVoid
from fp.algebra._derived import _map2_as, product as _family_product
from fp.callables._transforms import _Pair, _ValueThunk, _Apply
from fp.callables.native import _Binary, _RaisingBinary, _NativeBinaryRef
from fp.callables.invoke import RepeatableBinary, RepeatableBorrow
from fp.callables._receiver import _OnceBorrowAvailable
from fp.callables._transforms import _ObserveOnce
from fp.callables.protocols import BinaryContract

from fp.iteration.reductions import _FoldMapRun, _FindMapRun, _ExtremumRun, _run_terminal, _IntSum, _SIMDSum
from fp.algebra.protocols import Monoid
from fp.algebra.collections import _take_array, _array_terminal, _dict_terminal, _string_dict_terminal
from std.builtin.variadics import TypeList
from std.builtin.rebind import rebind_var, downcast
from std.collections import Array, Deque, LinkedList, StringDict, KeyElement
from std.hash import Hasher
from fp.data import Result
from fp.callables.protocols import BorrowCallContract, ThunkContract
from fp.callables.native import _Thunk, _RaisingThunk
from fp.algebra.protocols import Functor, Filterable, FunctorFilter, Monad, Traversable, Applicative
from fp.algebra._derived import _Same
from fp.algebra.collections import _ArrayFamily, _DequeFamily, _LinkedListFamily, _DictFamily, _StringDictFamily
from fp.algebra.operations import map as _family_map, _ErrorProbe, _map_native
from fp.callables.native import _Unary, _RaisingUnary, _NativeUnaryRef, _Borrowing, _RaisingBorrowing, _NativeBorrowRef
from fp.algebra.filtering import filter as _family_filter, filter_not as _family_filter_not, _filter_native
from fp.callables._predicates import _Negated
from fp.callables._transforms import _Fill, _Replace, _TupleWith, _Observe
from fp.callables.protocols import UnaryContract
from fp.callables.protocols import Unary, Binary, BorrowCallable
from fp.callables.native import _Thin1F, _LazyUnary, NativeUnary
from fp._internal.errors import _CommonError, _ErrorCompatible, _propagate_error
from ._pipeline import _PipelineRunner, _pipe_at
from .composition import Composition
from ._stages import _Plan, _check_stage, _stage_shared
from fp.iteration.folds import fold_left as _fold_left


from fp.algebra._accumulation import _FirstPresent
from fp.algebra._effect_combinators import _SearchStep, _fold_map_effect
from fp.callables.invoke import RepeatableUnary


comptime _PipelineResult[A: Movable & Deinitable, Results: TypeList[Trait=Movable & Deinitable, ...]]: Movable & Deinitable = A if Results.length == 0 else Results[Results.length - 1]


def identity[T: Movable](var value: T) -> T:
    """Return `value` unchanged, moving it.

    Parameters:
        T: The value's type.

    Args:
        value: The value, consumed.

    Returns:
        `value` itself; nothing is copied.
    """
    return value^


def pipe[T: Movable](var value: T) -> T:
    """Return `value` unchanged: a pipeline with no stages."""
    return value^


def pipe[A: Movable, R: Movable, //,
         F: def(var A) -> R](var value: A, function: F) -> R:
    """Apply one pure stage: a plain function or a closure."""
    return function(value^)


def pipe[A: Movable, R: Movable, E: AnyType, //,
         F: def(var A) raises E -> R](var value: A, function: F) raises E -> R:
    """Apply one raising stage; its error type is kept."""
    comptime if E == Never:
        return _call_native_never[A, R, F](function, value^)
    else:
        return function(value^)


def pipe[A: Movable & Deinitable, F: Unary](
    var value: A, function: F
) raises F.Error -> F.Out where F.Arg == A:
    """Apply one library `Unary` value, such as a partial or a composition."""
    return function.call(rebind_var[F.Arg](value^))


# Value names the whole pipeline payload, leaving T available for its elements.
# Mojo 1.1's captured-function evidence needs the canonical T/U parameter names
# in the lazy signatures below, including callbacks with origin-bearing results.
struct Piped[Value: Movable & Deinitable](Movable):
    """A value in an eager chained pipeline, started by `piped(value)`.

    Each `then` applies one stage immediately, as `pipe(value, f)` does, and
    infers that stage's types from its own call, so a chain has no stage limit
    and takes plain functions, closures and library `Unary` values alike. `get`
    extracts the stored value. `map` preserves supported native containers and
    maps their payloads immediately; `map[I]` uses an explicit Functor family,
    including its evaluation and error semantics. `filter` and `filter_not`
    preserve supported containers; `fold_left` consumes an iterable immediately. `get` does
    not trigger evaluation. Use `iterated(source).map(f)` for lazy element mapping.

    Parameters:
        Value: The type of the value the chain holds.
    """
    var value: Self.Value
    """The value the chain holds."""

    def __init__(out self, var value: Self.Value):
        self.value = value^


    # --- Result combinators (generated) ---
    # Generated by scripts/generate_result_syntax.py; execution stays in Result and shared callable adapters.

    def ensure[T: Movable & Deinitable, Failure: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, G: BorrowCallContract & Movable & Deinitable](deinit self, var predicate: C, var make_error: G) raises _CommonError[C.Failure, G.Failure] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C.Payload == T and C.Result == Bool and G.Payload == T and G.Result == Failure:
        """Keep an accepted success or construct a stored error from its borrowed value.

        The predicate runs only on Ok; the error factory runs only when the predicate returns False. Both borrow the success payload. The original Err passes through unchanged. Native errors propagate unchanged; they never become stored Err values. Native callbacks are borrowed in place; library callbacks are consumed and use their declared receiver mode. Shared partial predicates and observers may instead be borrowed by name; an explicit move retains the owning form.

        Parameters:
            T: The Result success type, including its origins.
            Failure: The stored error type, including its origins.
            C: The callback type, retaining its receiver, input, result and native error.
            G: The selected continuation type, retaining its receiver and native error.

        Args:
            predicate: The consumed borrowing predicate returning Bool.
            make_error: The consumed borrowing factory returning the stored error type.

        Returns:
            Keep an accepted success or construct a stored error from its borrowed value.

        Raises:
            The exact callback error; Never for non-raising callbacks. Two callbacks must share a native error type, or one must be non-raising.
        """
        return Piped(rebind_var[Result[T, Failure]](self.value^).ensure(predicate^, make_error^))

    def ensure[T: Movable & Deinitable, Failure: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, Q: AnyType, S: Movable & Deinitable, q: ImmOrigin, //, G: _Borrowing[Q, S]](deinit self, var predicate: C, ref[q] make_error: G) raises _CommonError[C.Failure, Never] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C.Payload == T and C.Result == Bool and Q == T and S == Failure:
        """Keep an accepted success or construct a stored error from its borrowed value."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).ensure(predicate^, _NativeBorrowRef[Q, S, Never, G, False, q](Pointer(to=make_error))))

    def ensure[T: Movable & Deinitable, Failure: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, Q: AnyType, S: Movable & Deinitable, q: ImmOrigin, //, Y: Movable & Deinitable, G: _RaisingBorrowing[Q, S, Y]](deinit self, var predicate: C, ref[q] make_error: G) raises _CommonError[C.Failure, Y] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C.Payload == T and C.Result == Bool and Q == T and S == Failure:
        """Keep an accepted success or construct a stored error from its borrowed value."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).ensure(predicate^, _NativeBorrowRef[Q, S, Y, G, True, q](Pointer(to=make_error))))

    def ensure[T: Movable & Deinitable, Failure: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, G: _BorrowViewable, q: ImmOrigin](deinit self, var predicate: C, ref[q] make_error: G) raises _CommonError[C.Failure, G._BorrowView[q].Failure] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C.Payload == T and C.Result == Bool and G._BorrowView[q].Payload == T and G._BorrowView[q].Result == Failure:
        """Keep an accepted success or construct a stored error from its borrowed value."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).ensure(predicate^, make_error._borrow_view()))

    def ensure[T: Movable & Deinitable, Failure: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, G: BorrowCallContract & Movable & Deinitable, //, C: _Borrowing[P, R]](deinit self, ref[o] predicate: C, var make_error: G) raises _CommonError[Never, G.Failure] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and P == T and R == Bool and G.Payload == T and G.Result == Failure:
        """Keep an accepted success or construct a stored error from its borrowed value."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).ensure(_NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=predicate)), make_error^))

    def ensure[T: Movable & Deinitable, Failure: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Q: AnyType, S: Movable & Deinitable, q: ImmOrigin, //, C: _Borrowing[P, R], G: _Borrowing[Q, S]](deinit self, ref[o] predicate: C, ref[q] make_error: G) raises _CommonError[Never, Never] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and P == T and R == Bool and Q == T and S == Failure:
        """Keep an accepted success or construct a stored error from its borrowed value."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).ensure(_NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=predicate)), _NativeBorrowRef[Q, S, Never, G, False, q](Pointer(to=make_error))))

    def ensure[T: Movable & Deinitable, Failure: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Q: AnyType, S: Movable & Deinitable, q: ImmOrigin, //, C: _Borrowing[P, R], Y: Movable & Deinitable, G: _RaisingBorrowing[Q, S, Y]](deinit self, ref[o] predicate: C, ref[q] make_error: G) raises _CommonError[Never, Y] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and P == T and R == Bool and Q == T and S == Failure:
        """Keep an accepted success or construct a stored error from its borrowed value."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).ensure(_NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=predicate)), _NativeBorrowRef[Q, S, Y, G, True, q](Pointer(to=make_error))))

    def ensure[T: Movable & Deinitable, Failure: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, G: _BorrowViewable, q: ImmOrigin, //, C: _Borrowing[P, R]](deinit self, ref[o] predicate: C, ref[q] make_error: G) raises _CommonError[Never, G._BorrowView[q].Failure] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and P == T and R == Bool and G._BorrowView[q].Payload == T and G._BorrowView[q].Result == Failure:
        """Keep an accepted success or construct a stored error from its borrowed value."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).ensure(_NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=predicate)), make_error._borrow_view()))

    def ensure[T: Movable & Deinitable, Failure: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, G: BorrowCallContract & Movable & Deinitable, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X]](deinit self, ref[o] predicate: C, var make_error: G) raises _CommonError[X, G.Failure] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and P == T and R == Bool and G.Payload == T and G.Result == Failure:
        """Keep an accepted success or construct a stored error from its borrowed value."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).ensure(_NativeBorrowRef[P, R, X, C, True, o](Pointer(to=predicate)), make_error^))

    def ensure[T: Movable & Deinitable, Failure: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Q: AnyType, S: Movable & Deinitable, q: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X], G: _Borrowing[Q, S]](deinit self, ref[o] predicate: C, ref[q] make_error: G) raises _CommonError[X, Never] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and P == T and R == Bool and Q == T and S == Failure:
        """Keep an accepted success or construct a stored error from its borrowed value."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).ensure(_NativeBorrowRef[P, R, X, C, True, o](Pointer(to=predicate)), _NativeBorrowRef[Q, S, Never, G, False, q](Pointer(to=make_error))))

    def ensure[T: Movable & Deinitable, Failure: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Q: AnyType, S: Movable & Deinitable, q: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X], Y: Movable & Deinitable, G: _RaisingBorrowing[Q, S, Y]](deinit self, ref[o] predicate: C, ref[q] make_error: G) raises _CommonError[X, Y] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and P == T and R == Bool and Q == T and S == Failure:
        """Keep an accepted success or construct a stored error from its borrowed value."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).ensure(_NativeBorrowRef[P, R, X, C, True, o](Pointer(to=predicate)), _NativeBorrowRef[Q, S, Y, G, True, q](Pointer(to=make_error))))

    def ensure[T: Movable & Deinitable, Failure: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, G: _BorrowViewable, q: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X]](deinit self, ref[o] predicate: C, ref[q] make_error: G) raises _CommonError[X, G._BorrowView[q].Failure] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and P == T and R == Bool and G._BorrowView[q].Payload == T and G._BorrowView[q].Result == Failure:
        """Keep an accepted success or construct a stored error from its borrowed value."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).ensure(_NativeBorrowRef[P, R, X, C, True, o](Pointer(to=predicate)), make_error._borrow_view()))

    def ensure[T: Movable & Deinitable, Failure: Movable & Deinitable, C: _BorrowViewable, o: ImmOrigin, G: BorrowCallContract & Movable & Deinitable](deinit self, ref[o] predicate: C, var make_error: G) raises _CommonError[C._BorrowView[o].Failure, G.Failure] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C._BorrowView[o].Payload == T and C._BorrowView[o].Result == Bool and G.Payload == T and G.Result == Failure:
        """Keep an accepted success or construct a stored error from its borrowed value."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).ensure(predicate._borrow_view(), make_error^))

    def ensure[T: Movable & Deinitable, Failure: Movable & Deinitable, C: _BorrowViewable, o: ImmOrigin, Q: AnyType, S: Movable & Deinitable, q: ImmOrigin, //, G: _Borrowing[Q, S]](deinit self, ref[o] predicate: C, ref[q] make_error: G) raises _CommonError[C._BorrowView[o].Failure, Never] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C._BorrowView[o].Payload == T and C._BorrowView[o].Result == Bool and Q == T and S == Failure:
        """Keep an accepted success or construct a stored error from its borrowed value."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).ensure(predicate._borrow_view(), _NativeBorrowRef[Q, S, Never, G, False, q](Pointer(to=make_error))))

    def ensure[T: Movable & Deinitable, Failure: Movable & Deinitable, C: _BorrowViewable, o: ImmOrigin, Q: AnyType, S: Movable & Deinitable, q: ImmOrigin, //, Y: Movable & Deinitable, G: _RaisingBorrowing[Q, S, Y]](deinit self, ref[o] predicate: C, ref[q] make_error: G) raises _CommonError[C._BorrowView[o].Failure, Y] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C._BorrowView[o].Payload == T and C._BorrowView[o].Result == Bool and Q == T and S == Failure:
        """Keep an accepted success or construct a stored error from its borrowed value."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).ensure(predicate._borrow_view(), _NativeBorrowRef[Q, S, Y, G, True, q](Pointer(to=make_error))))

    def ensure[T: Movable & Deinitable, Failure: Movable & Deinitable, C: _BorrowViewable, o: ImmOrigin, G: _BorrowViewable, q: ImmOrigin](deinit self, ref[o] predicate: C, ref[q] make_error: G) raises _CommonError[C._BorrowView[o].Failure, G._BorrowView[q].Failure] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C._BorrowView[o].Payload == T and C._BorrowView[o].Result == Bool and G._BorrowView[q].Payload == T and G._BorrowView[q].Result == Failure:
        """Keep an accepted success or construct a stored error from its borrowed value."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).ensure(predicate._borrow_view(), make_error._borrow_view()))

    def recover[T: Movable & Deinitable, Failure: Movable & Deinitable, C: UnaryContract & Movable & Deinitable](deinit self, var function: C) raises C.Error -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C.Arg == Failure and C.Out == T:
        """Recover a stored error as a success, retaining the Result error type.

        The callback consumes the error and returns the original success type. Ok passes through unchanged. This returns Result[T, E], not an unwrapped value. Native errors propagate unchanged; they never become stored Err values. Native callbacks are borrowed in place; library callbacks are consumed and use their declared receiver mode.

        Parameters:
            T: The Result success type, including its origins.
            Failure: The stored error type, including its origins.
            C: The callback type, retaining its receiver, input, result and native error.

        Args:
            function: The callback, consumed and invoked at most once on the selected branch.

        Returns:
            Recover a stored error as a success, retaining the Result error type.

        Raises:
            The exact callback error; Never for non-raising callbacks. Two callbacks must share a native error type, or one must be non-raising.
        """
        return Piped(rebind_var[Result[T, Failure]](self.value^).recover(function^))

    def recover[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, C: _Unary[A, R]](deinit self, ref[o] function: C) raises Never -> Piped[Result[R, A]] where Self.Value == Result[R, A] and A == A and R == R:
        """Recover a stored error as a success, retaining the Result error type."""
        return Piped(rebind_var[Result[R, A]](self.value^).recover(function))

    def recover[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingUnary[A, R, X]](deinit self, ref[o] function: C) raises X -> Piped[Result[R, A]] where Self.Value == Result[R, A] and A == A and R == R:
        """Recover a stored error as a success, retaining the Result error type."""
        return Piped(rebind_var[Result[R, A]](self.value^).recover[X=X](function))

    def tap_err[T: Movable & Deinitable, Failure: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](deinit self, var function: C) raises C.Failure -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C.Payload == Failure:
        """Inspect a borrowed stored error and retain the Result.

        The inspector runs only on Err. Its return value is discarded; the error is moved back unchanged. Ok passes through without inspection. Native errors propagate unchanged; they never become stored Err values. Native callbacks are borrowed in place; library callbacks are consumed and use their declared receiver mode. Shared partial predicates and observers may instead be borrowed by name; an explicit move retains the owning form.

        Parameters:
            T: The Result success type, including its origins.
            Failure: The stored error type, including its origins.
            C: The callback type, retaining its receiver, input, result and native error.

        Args:
            function: The callback, consumed and invoked at most once on the selected branch.

        Returns:
            Inspect a borrowed stored error and retain the Result.

        Raises:
            The exact callback error; Never for non-raising callbacks. Two callbacks must share a native error type, or one must be non-raising.
        """
        return Piped(rebind_var[Result[T, Failure]](self.value^).tap_err(function^))

    def tap_err[T: Movable & Deinitable, Failure: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, C: _Borrowing[P, R]](deinit self, ref[o] function: C) raises Never -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and P == Failure:
        """Inspect a borrowed stored error and retain the Result."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).tap_err(_NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=function))))

    def tap_err[T: Movable & Deinitable, Failure: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X]](deinit self, ref[o] function: C) raises X -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and P == Failure:
        """Inspect a borrowed stored error and retain the Result."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).tap_err(_NativeBorrowRef[P, R, X, C, True, o](Pointer(to=function))))

    def tap_err[T: Movable & Deinitable, Failure: Movable & Deinitable, C: _BorrowViewable, o: ImmOrigin](deinit self, ref[o] function: C) raises C._BorrowView[o].Failure -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C._BorrowView[o].Payload == Failure:
        """Inspect a borrowed stored error and retain the Result."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).tap_err(function._borrow_view()))

    def recover_if[T: Movable & Deinitable, Failure: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable](deinit self, var predicate: C, var function: G) raises _CommonError[C.Failure, G.Error] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C.Payload == Failure and C.Result == Bool and G.Arg == Failure and G.Out == T:
        """Recover a matching stored error as a success.

        Only Err runs the borrowing predicate. On True, the recovery consumes the error and returns the success type. On False, the original error remains. The stored error type stays unchanged. Native errors propagate unchanged; they never become stored Err values. Native callbacks are borrowed in place; library callbacks are consumed and use their declared receiver mode. Shared partial predicates and observers may instead be borrowed by name; an explicit move retains the owning form.

        Parameters:
            T: The Result success type, including its origins.
            Failure: The stored error type, including its origins.
            C: The callback type, retaining its receiver, input, result and native error.
            G: The selected continuation type, retaining its receiver and native error.

        Args:
            predicate: The consumed borrowing predicate returning Bool.
            function: The recovery, consumed and called only for matching errors; it consumes the stored error.

        Returns:
            Recover a matching stored error as a success.

        Raises:
            The exact callback error; Never for non-raising callbacks. Two callbacks must share a native error type, or one must be non-raising.
        """
        return Piped(rebind_var[Result[T, Failure]](self.value^).recover_if(predicate^, function^))

    def recover_if[T: Movable & Deinitable, Failure: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, G: _Unary[Q, S]](deinit self, var predicate: C, ref[q] function: G) raises C.Failure -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C.Payload == Failure and C.Result == Bool and Q == Failure and S == T:
        """Recover a matching stored error as a success."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).recover_if(predicate^, function))

    def recover_if[T: Movable & Deinitable, Failure: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, Y: Movable & Deinitable, G: _RaisingUnary[Q, S, Y]](deinit self, var predicate: C, ref[q] function: G) raises _CommonError[C.Failure, Y] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C.Payload == Failure and C.Result == Bool and Q == Failure and S == T:
        """Recover a matching stored error as a success."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).recover_if[Y=Y](predicate^, function))

    def recover_if[T: Movable & Deinitable, Failure: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, C: _Borrowing[P, R]](deinit self, ref[o] predicate: C, var function: G) raises _CommonError[Never, G.Error] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and P == Failure and R == Bool and G.Arg == Failure and G.Out == T:
        """Recover a matching stored error as a success."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).recover_if(_NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=predicate)), function^))

    def recover_if[T: Movable & Deinitable, Failure: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, C: _Borrowing[P, R], G: _Unary[Q, S]](deinit self, ref[o] predicate: C, ref[q] function: G) raises Never -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and P == Failure and R == Bool and Q == Failure and S == T:
        """Recover a matching stored error as a success."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).recover_if(_NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=predicate)), function))

    def recover_if[T: Movable & Deinitable, Failure: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, C: _Borrowing[P, R], Y: Movable & Deinitable, G: _RaisingUnary[Q, S, Y]](deinit self, ref[o] predicate: C, ref[q] function: G) raises _CommonError[Never, Y] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and P == Failure and R == Bool and Q == Failure and S == T:
        """Recover a matching stored error as a success."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).recover_if[Y=Y](_NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=predicate)), function))

    def recover_if[T: Movable & Deinitable, Failure: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X]](deinit self, ref[o] predicate: C, var function: G) raises _CommonError[X, G.Error] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and P == Failure and R == Bool and G.Arg == Failure and G.Out == T:
        """Recover a matching stored error as a success."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).recover_if(_NativeBorrowRef[P, R, X, C, True, o](Pointer(to=predicate)), function^))

    def recover_if[T: Movable & Deinitable, Failure: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X], G: _Unary[Q, S]](deinit self, ref[o] predicate: C, ref[q] function: G) raises X -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and P == Failure and R == Bool and Q == Failure and S == T:
        """Recover a matching stored error as a success."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).recover_if(_NativeBorrowRef[P, R, X, C, True, o](Pointer(to=predicate)), function))

    def recover_if[T: Movable & Deinitable, Failure: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X], Y: Movable & Deinitable, G: _RaisingUnary[Q, S, Y]](deinit self, ref[o] predicate: C, ref[q] function: G) raises _CommonError[X, Y] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and P == Failure and R == Bool and Q == Failure and S == T:
        """Recover a matching stored error as a success."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).recover_if[Y=Y](_NativeBorrowRef[P, R, X, C, True, o](Pointer(to=predicate)), function))

    def recover_if[T: Movable & Deinitable, Failure: Movable & Deinitable, C: _BorrowViewable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable](deinit self, ref[o] predicate: C, var function: G) raises _CommonError[C._BorrowView[o].Failure, G.Error] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C._BorrowView[o].Payload == Failure and C._BorrowView[o].Result == Bool and G.Arg == Failure and G.Out == T:
        """Recover a matching stored error as a success."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).recover_if(predicate._borrow_view(), function^))

    def recover_if[T: Movable & Deinitable, Failure: Movable & Deinitable, C: _BorrowViewable, o: ImmOrigin, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, G: _Unary[Q, S]](deinit self, ref[o] predicate: C, ref[q] function: G) raises C._BorrowView[o].Failure -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C._BorrowView[o].Payload == Failure and C._BorrowView[o].Result == Bool and Q == Failure and S == T:
        """Recover a matching stored error as a success."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).recover_if(predicate._borrow_view(), function))

    def recover_if[T: Movable & Deinitable, Failure: Movable & Deinitable, C: _BorrowViewable, o: ImmOrigin, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, Y: Movable & Deinitable, G: _RaisingUnary[Q, S, Y]](deinit self, ref[o] predicate: C, ref[q] function: G) raises _CommonError[C._BorrowView[o].Failure, Y] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C._BorrowView[o].Payload == Failure and C._BorrowView[o].Result == Bool and Q == Failure and S == T:
        """Recover a matching stored error as a success."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).recover_if[Y=Y](predicate._borrow_view(), function))

    def or_else_if[T: Movable & Deinitable, Failure: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable](deinit self, var predicate: C, var function: G) raises _CommonError[C.Failure, G.Error] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C.Payload == Failure and C.Result == Bool and G.Arg == Failure and G.Out == Result[T, Failure]:
        """Continue a matching stored error with a Result.

        Only Err runs the borrowing predicate. On True, the recovery consumes the error and returns Result[T, E]; on False, the original error remains. Both success and stored error types stay unchanged. Native errors propagate unchanged; they never become stored Err values. Native callbacks are borrowed in place; library callbacks are consumed and use their declared receiver mode. Shared partial predicates and observers may instead be borrowed by name; an explicit move retains the owning form.

        Parameters:
            T: The Result success type, including its origins.
            Failure: The stored error type, including its origins.
            C: The callback type, retaining its receiver, input, result and native error.
            G: The selected continuation type, retaining its receiver and native error.

        Args:
            predicate: The consumed borrowing predicate returning Bool.
            function: The recovery, consumed and called only for matching errors; it consumes the stored error.

        Returns:
            Continue a matching stored error with a Result.

        Raises:
            The exact callback error; Never for non-raising callbacks. Two callbacks must share a native error type, or one must be non-raising.
        """
        return Piped(rebind_var[Result[T, Failure]](self.value^).or_else_if(predicate^, function^))

    def or_else_if[T: Movable & Deinitable, Failure: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, G: _Unary[Q, S]](deinit self, var predicate: C, ref[q] function: G) raises C.Failure -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C.Payload == Failure and C.Result == Bool and Q == Failure and S == Result[T, Failure]:
        """Continue a matching stored error with a Result."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).or_else_if(predicate^, function))

    def or_else_if[T: Movable & Deinitable, Failure: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, Y: Movable & Deinitable, G: _RaisingUnary[Q, S, Y]](deinit self, var predicate: C, ref[q] function: G) raises _CommonError[C.Failure, Y] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C.Payload == Failure and C.Result == Bool and Q == Failure and S == Result[T, Failure]:
        """Continue a matching stored error with a Result."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).or_else_if[Y=Y](predicate^, function))

    def or_else_if[T: Movable & Deinitable, Failure: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, C: _Borrowing[P, R]](deinit self, ref[o] predicate: C, var function: G) raises _CommonError[Never, G.Error] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and P == Failure and R == Bool and G.Arg == Failure and G.Out == Result[T, Failure]:
        """Continue a matching stored error with a Result."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).or_else_if(_NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=predicate)), function^))

    def or_else_if[T: Movable & Deinitable, Failure: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, C: _Borrowing[P, R], G: _Unary[Q, S]](deinit self, ref[o] predicate: C, ref[q] function: G) raises Never -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and P == Failure and R == Bool and Q == Failure and S == Result[T, Failure]:
        """Continue a matching stored error with a Result."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).or_else_if(_NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=predicate)), function))

    def or_else_if[T: Movable & Deinitable, Failure: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, C: _Borrowing[P, R], Y: Movable & Deinitable, G: _RaisingUnary[Q, S, Y]](deinit self, ref[o] predicate: C, ref[q] function: G) raises _CommonError[Never, Y] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and P == Failure and R == Bool and Q == Failure and S == Result[T, Failure]:
        """Continue a matching stored error with a Result."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).or_else_if[Y=Y](_NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=predicate)), function))

    def or_else_if[T: Movable & Deinitable, Failure: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X]](deinit self, ref[o] predicate: C, var function: G) raises _CommonError[X, G.Error] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and P == Failure and R == Bool and G.Arg == Failure and G.Out == Result[T, Failure]:
        """Continue a matching stored error with a Result."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).or_else_if(_NativeBorrowRef[P, R, X, C, True, o](Pointer(to=predicate)), function^))

    def or_else_if[T: Movable & Deinitable, Failure: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X], G: _Unary[Q, S]](deinit self, ref[o] predicate: C, ref[q] function: G) raises X -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and P == Failure and R == Bool and Q == Failure and S == Result[T, Failure]:
        """Continue a matching stored error with a Result."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).or_else_if(_NativeBorrowRef[P, R, X, C, True, o](Pointer(to=predicate)), function))

    def or_else_if[T: Movable & Deinitable, Failure: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X], Y: Movable & Deinitable, G: _RaisingUnary[Q, S, Y]](deinit self, ref[o] predicate: C, ref[q] function: G) raises _CommonError[X, Y] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and P == Failure and R == Bool and Q == Failure and S == Result[T, Failure]:
        """Continue a matching stored error with a Result."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).or_else_if[Y=Y](_NativeBorrowRef[P, R, X, C, True, o](Pointer(to=predicate)), function))

    def or_else_if[T: Movable & Deinitable, Failure: Movable & Deinitable, C: _BorrowViewable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable](deinit self, ref[o] predicate: C, var function: G) raises _CommonError[C._BorrowView[o].Failure, G.Error] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C._BorrowView[o].Payload == Failure and C._BorrowView[o].Result == Bool and G.Arg == Failure and G.Out == Result[T, Failure]:
        """Continue a matching stored error with a Result."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).or_else_if(predicate._borrow_view(), function^))

    def or_else_if[T: Movable & Deinitable, Failure: Movable & Deinitable, C: _BorrowViewable, o: ImmOrigin, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, G: _Unary[Q, S]](deinit self, ref[o] predicate: C, ref[q] function: G) raises C._BorrowView[o].Failure -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C._BorrowView[o].Payload == Failure and C._BorrowView[o].Result == Bool and Q == Failure and S == Result[T, Failure]:
        """Continue a matching stored error with a Result."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).or_else_if(predicate._borrow_view(), function))

    def or_else_if[T: Movable & Deinitable, Failure: Movable & Deinitable, C: _BorrowViewable, o: ImmOrigin, Q: Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, Y: Movable & Deinitable, G: _RaisingUnary[Q, S, Y]](deinit self, ref[o] predicate: C, ref[q] function: G) raises _CommonError[C._BorrowView[o].Failure, Y] -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C._BorrowView[o].Payload == Failure and C._BorrowView[o].Result == Bool and Q == Failure and S == Result[T, Failure]:
        """Continue a matching stored error with a Result."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).or_else_if[Y=Y](predicate._borrow_view(), function))

    def flat_tap_err[T: Movable & Deinitable, Failure: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](deinit self, var function: C) raises C.Failure -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C.Payload == Failure and C.Result == Result[downcast[C.Result, _ResultType].Value, Failure]:
        """Sequence a borrowed error projection and retain the original error on success.

        The projection runs only on Err and must return Result[U, E]. Its Ok payload is discarded and the original error is retained; its Err replaces that error. Ok passes through unchanged. Native errors propagate unchanged; they never become stored Err values. Native callbacks are borrowed in place; library callbacks are consumed and use their declared receiver mode. Shared partial predicates and observers may instead be borrowed by name; an explicit move retains the owning form.

        Parameters:
            T: The Result success type, including its origins.
            Failure: The stored error type, including its origins.
            C: The callback type, retaining its receiver, input, result and native error.

        Args:
            function: The callback, consumed and invoked at most once on the selected branch.

        Returns:
            Sequence a borrowed error projection and retain the original error on success.

        Raises:
            The exact callback error; Never for non-raising callbacks. Two callbacks must share a native error type, or one must be non-raising.
        """
        return Piped(rebind_var[Result[T, Failure]](self.value^).flat_tap_err(function^))

    def flat_tap_err[T: Movable & Deinitable, Failure: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, C: def(Failure) -> R, U: Movable & Deinitable = downcast[R, _ResultType].Value](deinit self, ref[o] function: C) raises Never -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and R == Result[downcast[R, _ResultType].Value, Failure] and U == downcast[R, _ResultType].Value:
        """Sequence a borrowed error projection and retain the original error on success."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).flat_tap_err(_NativeBorrowRef[Failure, R, Never, C, False, o](Pointer(to=function))))

    def flat_tap_err[T: Movable & Deinitable, Failure: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, X: Movable & Deinitable, C: def(Failure) raises X -> R, U: Movable & Deinitable = downcast[R, _ResultType].Value](deinit self, ref[o] function: C) raises X -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and R == Result[downcast[R, _ResultType].Value, Failure] and U == downcast[R, _ResultType].Value:
        """Sequence a borrowed error projection and retain the original error on success."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).flat_tap_err(_NativeBorrowRef[Failure, R, X, C, True, o](Pointer(to=function))))

    def flat_tap_err[T: Movable & Deinitable, Failure: Movable & Deinitable, C: _BorrowViewable, o: ImmOrigin](deinit self, ref[o] function: C) raises C._BorrowView[o].Failure -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C._BorrowView[o].Payload == Failure and C._BorrowView[o].Result == Result[downcast[C._BorrowView[o].Result, _ResultType].Value, Failure]:
        """Sequence a borrowed error projection and retain the original error on success."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).flat_tap_err(function._borrow_view()))

    def attempt_tap[T: Movable & Deinitable, Failure: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](deinit self, var function: C) raises C.Failure -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C.Payload == Result[T, Failure] and C.Result == Result[downcast[C.Result, _ResultType].Value, Failure]:
        """Sequence an observer of the whole Result and retain its outcome on observer success.

        The observer borrows the entire Result, runs once on either branch and returns Result[U, E]. Its Ok payload is discarded and the original Result is retained; its Err replaces the original outcome. Native raised errors remain raised. Native errors propagate unchanged; they never become stored Err values. Native callbacks are borrowed in place; library callbacks are consumed and use their declared receiver mode. Shared partial predicates and observers may instead be borrowed by name; an explicit move retains the owning form.

        Parameters:
            T: The Result success type, including its origins.
            Failure: The stored error type, including its origins.
            C: The callback type, retaining its receiver, input, result and native error.

        Args:
            function: The callback, consumed and invoked at most once on the selected branch.

        Returns:
            Sequence an observer of the whole Result and retain its outcome on observer success.

        Raises:
            The exact callback error; Never for non-raising callbacks. Two callbacks must share a native error type, or one must be non-raising.
        """
        return Piped(rebind_var[Result[T, Failure]](self.value^).attempt_tap(function^))

    def attempt_tap[T: Movable & Deinitable, Failure: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, C: def(Result[T, Failure]) -> R, U: Movable & Deinitable = downcast[R, _ResultType].Value](deinit self, ref[o] function: C) raises Never -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and R == Result[downcast[R, _ResultType].Value, Failure] and U == downcast[R, _ResultType].Value:
        """Sequence an observer of the whole Result and retain its outcome on observer success."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).attempt_tap(_NativeBorrowRef[Result[T, Failure], R, Never, C, False, o](Pointer(to=function))))

    def attempt_tap[T: Movable & Deinitable, Failure: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, X: Movable & Deinitable, C: def(Result[T, Failure]) raises X -> R, U: Movable & Deinitable = downcast[R, _ResultType].Value](deinit self, ref[o] function: C) raises X -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and R == Result[downcast[R, _ResultType].Value, Failure] and U == downcast[R, _ResultType].Value:
        """Sequence an observer of the whole Result and retain its outcome on observer success."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).attempt_tap(_NativeBorrowRef[Result[T, Failure], R, X, C, True, o](Pointer(to=function))))

    def attempt_tap[T: Movable & Deinitable, Failure: Movable & Deinitable, C: _BorrowViewable, o: ImmOrigin](deinit self, ref[o] function: C) raises C._BorrowView[o].Failure -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C._BorrowView[o].Payload == Result[T, Failure] and C._BorrowView[o].Result == Result[downcast[C._BorrowView[o].Result, _ResultType].Value, Failure]:
        """Sequence an observer of the whole Result and retain its outcome on observer success."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).attempt_tap(function._borrow_view()))

    def map_err[T: Movable & Deinitable, Failure: Movable & Deinitable, C: UnaryContract & Movable & Deinitable](deinit self, var function: C) raises C.Error -> Piped[Result[T, C.Out]] where Self.Value == Result[T, Failure] and C.Arg == Failure:
        """Transform the stored error of a Result.

        This forwards to Result.map_err, including changes to the stored error type. Ok passes through unchanged. Native errors propagate unchanged; they never become stored Err values. Native callbacks are borrowed in place; library callbacks are consumed and use their declared receiver mode.

        Parameters:
            T: The Result success type, including its origins.
            Failure: The stored error type, including its origins.
            C: The callback type, retaining its receiver, input, result and native error.

        Args:
            function: The callback, consumed and invoked at most once on the selected branch.

        Returns:
            Transform the stored error of a Result.

        Raises:
            The exact callback error; Never for non-raising callbacks. Two callbacks must share a native error type, or one must be non-raising.
        """
        return Piped(rebind_var[Result[T, Failure]](self.value^).map_err(function^))

    def map_err[T: Movable & Deinitable, Failure: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, C: _Unary[A, R]](deinit self, ref[o] function: C) raises Never -> Piped[Result[T, R]] where Self.Value == Result[T, Failure] and A == Failure:
        """Transform the stored error of a Result."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).map_err(_NativeUnaryRef[A, R, Never, C, False, o](Pointer(to=function))))

    def map_err[T: Movable & Deinitable, Failure: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingUnary[A, R, X]](deinit self, ref[o] function: C) raises X -> Piped[Result[T, R]] where Self.Value == Result[T, Failure] and A == Failure:
        """Transform the stored error of a Result."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).map_err(_NativeUnaryRef[A, R, X, C, True, o](Pointer(to=function))))

    def or_else[T: Movable & Deinitable, Failure: Movable & Deinitable, C: UnaryContract & Movable & Deinitable](deinit self, var function: C) raises C.Error -> Piped[C.Out] where Self.Value == Result[T, Failure] and C.Arg == Failure:
        """Continue a failed Result with the callback Result.

        This forwards to Result.or_else, including changes to the stored error type. The success type stays the same; Ok passes through unchanged. Native errors propagate unchanged; they never become stored Err values. Native callbacks are borrowed in place; library callbacks are consumed and use their declared receiver mode.

        Parameters:
            T: The Result success type, including its origins.
            Failure: The stored error type, including its origins.
            C: The callback type, retaining its receiver, input, result and native error.

        Args:
            function: The callback, consumed and invoked at most once on the selected branch.

        Returns:
            Continue a failed Result with the callback Result.

        Raises:
            The exact callback error; Never for non-raising callbacks. Two callbacks must share a native error type, or one must be non-raising.
        """
        return Piped(rebind_var[Result[T, Failure]](self.value^).or_else(function^))

    def or_else[T: Movable & Deinitable, Failure: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, C: _Unary[A, R], U: Movable & Deinitable = downcast[R, _ResultType].Error](deinit self, ref[o] function: C) raises Never -> Piped[R] where Self.Value == Result[T, Failure] and A == Failure and R == Result[T, U]:
        """Continue a failed Result with the callback Result."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).or_else(_NativeUnaryRef[A, R, Never, C, False, o](Pointer(to=function))))

    def or_else[T: Movable & Deinitable, Failure: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingUnary[A, R, X], U: Movable & Deinitable = downcast[R, _ResultType].Error](deinit self, ref[o] function: C) raises X -> Piped[R] where Self.Value == Result[T, Failure] and A == Failure and R == Result[T, U]:
        """Continue a failed Result with the callback Result."""
        return Piped(rebind_var[Result[T, Failure]](self.value^).or_else(_NativeUnaryRef[A, R, X, C, True, o](Pointer(to=function))))

    def map_both[T: Movable & Deinitable, Failure: Movable & Deinitable, C: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable](deinit self, var on_ok: C, var on_err: G) raises _CommonError[C.Error, G.Error] -> Piped[Result[C.Out, G.Out]] where Self.Value == Result[T, Failure] and C.Arg == T and G.Arg == Failure and (C.Error == Never or G.Error == Never or C.Error == G.Error):
        """Transform either payload, preserving its Result constructor.

        The selected handler consumes its payload. The success and stored error types may both change. Execution is immediate. Native handlers are borrowed in place; library handlers are consumed and use their declared receiver mode, including disposal of the skipped handler. Payloads, captures and native raised errors keep their ownership and origins. No Copyable requirement is added.

        Parameters:
            T: The source success type, including its origins.
            Failure: The source stored error type, including its origins.
            C: The success handler type.
            G: The error handler type.

        Args:
            on_ok: The handler consuming the success payload.
            on_err: The handler consuming the error payload.

        Returns:
            Transform either payload, preserving its Result constructor.

        Raises:
            The selected handler native error, unchanged. Both must share an error type, or one must be non-raising.
        """
        return Piped(rebind_var[Result[C.Out, G.Out]](rebind_var[Result[T, Failure]](self.value^).map_both(on_ok^, on_err^)))

    def map_both[T: Movable & Deinitable, Failure: Movable & Deinitable, C: UnaryContract & Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, G: def(var Failure) -> S](deinit self, var on_ok: C, ref[q] on_err: G) raises C.Error -> Piped[Result[C.Out, S]] where Self.Value == Result[T, Failure] and C.Arg == T:
        """Transform either payload, preserving its Result constructor."""
        return Piped(rebind_var[Result[C.Out, S]](rebind_var[Result[T, Failure]](self.value^).map_both(on_ok^, on_err)))

    def map_both[T: Movable & Deinitable, Failure: Movable & Deinitable, C: UnaryContract & Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, Y: Movable & Deinitable, G: def(var Failure) raises Y -> S](deinit self, var on_ok: C, ref[q] on_err: G) raises _CommonError[C.Error, Y] -> Piped[Result[C.Out, S]] where Self.Value == Result[T, Failure] and C.Arg == T and (C.Error == Never or Y == Never or C.Error == Y):
        """Transform either payload, preserving its Result constructor."""
        return Piped(rebind_var[Result[C.Out, S]](rebind_var[Result[T, Failure]](self.value^).map_both[Y=Y](on_ok^, on_err)))

    def map_both[T: Movable & Deinitable, Failure: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, C: def(var T) -> R](deinit self, ref[o] on_ok: C, var on_err: G) raises G.Error -> Piped[Result[R, G.Out]] where Self.Value == Result[T, Failure] and G.Arg == Failure:
        """Transform either payload, preserving its Result constructor."""
        return Piped(rebind_var[Result[R, G.Out]](rebind_var[Result[T, Failure]](self.value^).map_both(on_ok, on_err^)))

    def map_both[T: Movable & Deinitable, Failure: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, S: Movable & Deinitable, q: ImmOrigin, //, C: def(var T) -> R, G: def(var Failure) -> S](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises Never -> Piped[Result[R, S]] where Self.Value == Result[T, Failure]:
        """Transform either payload, preserving its Result constructor."""
        return Piped(rebind_var[Result[R, S]](rebind_var[Result[T, Failure]](self.value^).map_both(on_ok, on_err)))

    def map_both[T: Movable & Deinitable, Failure: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, S: Movable & Deinitable, q: ImmOrigin, //, C: def(var T) -> R, Y: Movable & Deinitable, G: def(var Failure) raises Y -> S](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises Y -> Piped[Result[R, S]] where Self.Value == Result[T, Failure]:
        """Transform either payload, preserving its Result constructor."""
        return Piped(rebind_var[Result[R, S]](rebind_var[Result[T, Failure]](self.value^).map_both[Y=Y](on_ok, on_err)))

    def map_both[T: Movable & Deinitable, Failure: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, X: Movable & Deinitable, C: def(var T) raises X -> R](deinit self, ref[o] on_ok: C, var on_err: G) raises _CommonError[X, G.Error] -> Piped[Result[R, G.Out]] where Self.Value == Result[T, Failure] and G.Arg == Failure and (X == Never or G.Error == Never or X == G.Error):
        """Transform either payload, preserving its Result constructor."""
        return Piped(rebind_var[Result[R, G.Out]](rebind_var[Result[T, Failure]](self.value^).map_both[X=X](on_ok, on_err^)))

    def map_both[T: Movable & Deinitable, Failure: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, S: Movable & Deinitable, q: ImmOrigin, //, X: Movable & Deinitable, C: def(var T) raises X -> R, G: def(var Failure) -> S](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises X -> Piped[Result[R, S]] where Self.Value == Result[T, Failure]:
        """Transform either payload, preserving its Result constructor."""
        return Piped(rebind_var[Result[R, S]](rebind_var[Result[T, Failure]](self.value^).map_both[X=X](on_ok, on_err)))

    def map_both[T: Movable & Deinitable, Failure: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, S: Movable & Deinitable, q: ImmOrigin, //, X: Movable & Deinitable, C: def(var T) raises X -> R, Y: Movable & Deinitable, G: def(var Failure) raises Y -> S](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises _CommonError[X, Y] -> Piped[Result[R, S]] where Self.Value == Result[T, Failure] and (X == Never or Y == Never or X == Y):
        """Transform either payload, preserving its Result constructor."""
        return Piped(rebind_var[Result[R, S]](rebind_var[Result[T, Failure]](self.value^).map_both[X=X, Y=Y](on_ok, on_err)))

    def redeem[T: Movable & Deinitable, Failure: Movable & Deinitable, C: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable](deinit self, var on_ok: C, var on_err: G) raises _CommonError[C.Error, G.Error] -> Piped[Result[C.Out, Failure]] where Self.Value == Result[T, Failure] and C.Arg == T and G.Arg == Failure and C.Out == G.Out and (C.Error == Never or G.Error == Never or C.Error == G.Error):
        """Turn either branch into a success with a common value type.

        Both handlers return the same value type. The selected result is wrapped in Ok, retaining the original stored error type. Execution is immediate. Native handlers are borrowed in place; library handlers are consumed and use their declared receiver mode, including disposal of the skipped handler. Payloads, captures and native raised errors keep their ownership and origins. No Copyable requirement is added.

        Parameters:
            T: The source success type, including its origins.
            Failure: The source stored error type, including its origins.
            C: The success handler type.
            G: The error handler type.

        Args:
            on_ok: The handler consuming the success payload.
            on_err: The handler consuming the error payload.

        Returns:
            Turn either branch into a success with a common value type.

        Raises:
            The selected handler native error, unchanged. Both must share an error type, or one must be non-raising.
        """
        return Piped(rebind_var[Result[C.Out, Failure]](rebind_var[Result[T, Failure]](self.value^).redeem(on_ok^, on_err^)))

    def redeem[T: Movable & Deinitable, Failure: Movable & Deinitable, C: UnaryContract & Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, G: def(var Failure) -> S](deinit self, var on_ok: C, ref[q] on_err: G) raises C.Error -> Piped[Result[C.Out, Failure]] where Self.Value == Result[T, Failure] and C.Arg == T and C.Out == S:
        """Turn either branch into a success with a common value type."""
        return Piped(rebind_var[Result[C.Out, Failure]](rebind_var[Result[T, Failure]](self.value^).redeem(on_ok^, on_err)))

    def redeem[T: Movable & Deinitable, Failure: Movable & Deinitable, C: UnaryContract & Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, Y: Movable & Deinitable, G: def(var Failure) raises Y -> S](deinit self, var on_ok: C, ref[q] on_err: G) raises _CommonError[C.Error, Y] -> Piped[Result[C.Out, Failure]] where Self.Value == Result[T, Failure] and C.Arg == T and C.Out == S and (C.Error == Never or Y == Never or C.Error == Y):
        """Turn either branch into a success with a common value type."""
        return Piped(rebind_var[Result[C.Out, Failure]](rebind_var[Result[T, Failure]](self.value^).redeem[Y=Y](on_ok^, on_err)))

    def redeem[T: Movable & Deinitable, Failure: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, C: def(var T) -> R](deinit self, ref[o] on_ok: C, var on_err: G) raises G.Error -> Piped[Result[R, Failure]] where Self.Value == Result[T, Failure] and G.Arg == Failure and R == G.Out:
        """Turn either branch into a success with a common value type."""
        return Piped(rebind_var[Result[R, Failure]](rebind_var[Result[T, Failure]](self.value^).redeem(on_ok, on_err^)))

    def redeem[T: Movable & Deinitable, Failure: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, S: Movable & Deinitable, q: ImmOrigin, //, C: def(var T) -> R, G: def(var Failure) -> S](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises Never -> Piped[Result[R, Failure]] where Self.Value == Result[T, Failure] and R == S:
        """Turn either branch into a success with a common value type."""
        return Piped(rebind_var[Result[R, Failure]](rebind_var[Result[T, Failure]](self.value^).redeem(on_ok, on_err)))

    def redeem[T: Movable & Deinitable, Failure: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, S: Movable & Deinitable, q: ImmOrigin, //, C: def(var T) -> R, Y: Movable & Deinitable, G: def(var Failure) raises Y -> S](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises Y -> Piped[Result[R, Failure]] where Self.Value == Result[T, Failure] and R == S:
        """Turn either branch into a success with a common value type."""
        return Piped(rebind_var[Result[R, Failure]](rebind_var[Result[T, Failure]](self.value^).redeem[Y=Y](on_ok, on_err)))

    def redeem[T: Movable & Deinitable, Failure: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, X: Movable & Deinitable, C: def(var T) raises X -> R](deinit self, ref[o] on_ok: C, var on_err: G) raises _CommonError[X, G.Error] -> Piped[Result[R, Failure]] where Self.Value == Result[T, Failure] and G.Arg == Failure and R == G.Out and (X == Never or G.Error == Never or X == G.Error):
        """Turn either branch into a success with a common value type."""
        return Piped(rebind_var[Result[R, Failure]](rebind_var[Result[T, Failure]](self.value^).redeem[X=X](on_ok, on_err^)))

    def redeem[T: Movable & Deinitable, Failure: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, S: Movable & Deinitable, q: ImmOrigin, //, X: Movable & Deinitable, C: def(var T) raises X -> R, G: def(var Failure) -> S](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises X -> Piped[Result[R, Failure]] where Self.Value == Result[T, Failure] and R == S:
        """Turn either branch into a success with a common value type."""
        return Piped(rebind_var[Result[R, Failure]](rebind_var[Result[T, Failure]](self.value^).redeem[X=X](on_ok, on_err)))

    def redeem[T: Movable & Deinitable, Failure: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, S: Movable & Deinitable, q: ImmOrigin, //, X: Movable & Deinitable, C: def(var T) raises X -> R, Y: Movable & Deinitable, G: def(var Failure) raises Y -> S](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises _CommonError[X, Y] -> Piped[Result[R, Failure]] where Self.Value == Result[T, Failure] and R == S and (X == Never or Y == Never or X == Y):
        """Turn either branch into a success with a common value type."""
        return Piped(rebind_var[Result[R, Failure]](rebind_var[Result[T, Failure]](self.value^).redeem[X=X, Y=Y](on_ok, on_err)))

    def redeem_with[T: Movable & Deinitable, Failure: Movable & Deinitable, C: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable](deinit self, var on_ok: C, var on_err: G) raises _CommonError[C.Error, G.Error] -> Piped[C.Out] where Self.Value == Result[T, Failure] and C.Arg == T and G.Arg == Failure and C.Out == G.Out and (C.Error == Never or G.Error == Never or C.Error == G.Error):
        """Continue either branch with the selected handler Result.

        Both handlers return the same Result type, which may change both success and stored error types. Only the original branch selects a handler; a returned Err never invokes the other handler. Execution is immediate. Native handlers are borrowed in place; library handlers are consumed and use their declared receiver mode, including disposal of the skipped handler. Payloads, captures and native raised errors keep their ownership and origins. No Copyable requirement is added.

        Parameters:
            T: The source success type, including its origins.
            Failure: The source stored error type, including its origins.
            C: The success handler type.
            G: The error handler type.

        Args:
            on_ok: The handler consuming the success payload.
            on_err: The handler consuming the error payload.

        Returns:
            Continue either branch with the selected handler Result.

        Raises:
            The selected handler native error, unchanged. Both must share an error type, or one must be non-raising.
        """
        return Piped(rebind_var[C.Out](rebind_var[Result[T, Failure]](self.value^).redeem_with(on_ok^, on_err^)))

    def redeem_with[T: Movable & Deinitable, Failure: Movable & Deinitable, C: UnaryContract & Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, G: def(var Failure) -> S](deinit self, var on_ok: C, ref[q] on_err: G) raises C.Error -> Piped[C.Out] where Self.Value == Result[T, Failure] and C.Arg == T and C.Out == S:
        """Continue either branch with the selected handler Result."""
        return Piped(rebind_var[C.Out](rebind_var[Result[T, Failure]](self.value^).redeem_with(on_ok^, on_err)))

    def redeem_with[T: Movable & Deinitable, Failure: Movable & Deinitable, C: UnaryContract & Movable & Deinitable, S: Movable & Deinitable, q: ImmOrigin, //, Y: Movable & Deinitable, G: def(var Failure) raises Y -> S](deinit self, var on_ok: C, ref[q] on_err: G) raises _CommonError[C.Error, Y] -> Piped[C.Out] where Self.Value == Result[T, Failure] and C.Arg == T and C.Out == S and (C.Error == Never or Y == Never or C.Error == Y):
        """Continue either branch with the selected handler Result."""
        return Piped(rebind_var[C.Out](rebind_var[Result[T, Failure]](self.value^).redeem_with[Y=Y](on_ok^, on_err)))

    def redeem_with[T: Movable & Deinitable, Failure: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, C: def(var T) -> R, U: Movable & Deinitable = downcast[R, _ResultType].Value, V: Movable & Deinitable = downcast[R, _ResultType].Error](deinit self, ref[o] on_ok: C, var on_err: G) raises G.Error -> Piped[R] where Self.Value == Result[T, Failure] and R == Result[U, V] and G.Arg == Failure and R == G.Out:
        """Continue either branch with the selected handler Result."""
        return Piped(rebind_var[R](rebind_var[Result[T, Failure]](self.value^).redeem_with[U=U, V=V](on_ok, on_err^)))

    def redeem_with[T: Movable & Deinitable, Failure: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, S: Movable & Deinitable, q: ImmOrigin, //, C: def(var T) -> R, G: def(var Failure) -> S, U: Movable & Deinitable = downcast[R, _ResultType].Value, V: Movable & Deinitable = downcast[R, _ResultType].Error](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises Never -> Piped[R] where Self.Value == Result[T, Failure] and R == Result[U, V] and R == S:
        """Continue either branch with the selected handler Result."""
        return Piped(rebind_var[R](rebind_var[Result[T, Failure]](self.value^).redeem_with[U=U, V=V](on_ok, on_err)))

    def redeem_with[T: Movable & Deinitable, Failure: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, S: Movable & Deinitable, q: ImmOrigin, //, C: def(var T) -> R, Y: Movable & Deinitable, G: def(var Failure) raises Y -> S, U: Movable & Deinitable = downcast[R, _ResultType].Value, V: Movable & Deinitable = downcast[R, _ResultType].Error](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises Y -> Piped[R] where Self.Value == Result[T, Failure] and R == Result[U, V] and R == S:
        """Continue either branch with the selected handler Result."""
        return Piped(rebind_var[R](rebind_var[Result[T, Failure]](self.value^).redeem_with[Y=Y, U=U, V=V](on_ok, on_err)))

    def redeem_with[T: Movable & Deinitable, Failure: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, X: Movable & Deinitable, C: def(var T) raises X -> R, U: Movable & Deinitable = downcast[R, _ResultType].Value, V: Movable & Deinitable = downcast[R, _ResultType].Error](deinit self, ref[o] on_ok: C, var on_err: G) raises _CommonError[X, G.Error] -> Piped[R] where Self.Value == Result[T, Failure] and R == Result[U, V] and G.Arg == Failure and R == G.Out and (X == Never or G.Error == Never or X == G.Error):
        """Continue either branch with the selected handler Result."""
        return Piped(rebind_var[R](rebind_var[Result[T, Failure]](self.value^).redeem_with[X=X, U=U, V=V](on_ok, on_err^)))

    def redeem_with[T: Movable & Deinitable, Failure: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, S: Movable & Deinitable, q: ImmOrigin, //, X: Movable & Deinitable, C: def(var T) raises X -> R, G: def(var Failure) -> S, U: Movable & Deinitable = downcast[R, _ResultType].Value, V: Movable & Deinitable = downcast[R, _ResultType].Error](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises X -> Piped[R] where Self.Value == Result[T, Failure] and R == Result[U, V] and R == S:
        """Continue either branch with the selected handler Result."""
        return Piped(rebind_var[R](rebind_var[Result[T, Failure]](self.value^).redeem_with[X=X, U=U, V=V](on_ok, on_err)))

    def redeem_with[T: Movable & Deinitable, Failure: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, S: Movable & Deinitable, q: ImmOrigin, //, X: Movable & Deinitable, C: def(var T) raises X -> R, Y: Movable & Deinitable, G: def(var Failure) raises Y -> S, U: Movable & Deinitable = downcast[R, _ResultType].Value, V: Movable & Deinitable = downcast[R, _ResultType].Error](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises _CommonError[X, Y] -> Piped[R] where Self.Value == Result[T, Failure] and R == Result[U, V] and R == S and (X == Never or Y == Never or X == Y):
        """Continue either branch with the selected handler Result."""
        return Piped(rebind_var[R](rebind_var[Result[T, Failure]](self.value^).redeem_with[X=X, Y=Y, U=U, V=V](on_ok, on_err)))

    # --- end Result combinators ---

    def tap[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Self where Self.Value == P:
        """Inspect the whole pipeline value once and continue with it unchanged.

        Parameters:
            P: The borrowed callback payload type, including its native origins.
            R: The native callback result type.
            o: The origin of the borrowed native callback.
            F: The callback type, retaining its receiver, captures and error contract.

        Args:
            function: The callback, borrowed in place; calls follow the operation's evaluation order.

        Returns:
            The unchanged whole pipeline value, after one inspection call.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        var inspect = _Observe[Self.Value, _NativeBorrowRef[P, R, Never, F, False, o], False](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function)))
        return Self(inspect.call(self.value^))

    def tap[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Self where Self.Value == P:
        """Inspect the whole pipeline value once and continue with it unchanged."""
        var inspect = _Observe[Self.Value, _NativeBorrowRef[P, R, E, F, True, o], False](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function)))
        return Self(inspect.call(self.value^))

    def tap[C: BorrowCallContract & Movable & Deinitable](deinit self, var function: C) raises C.Failure -> Self where C.Payload == Self.Value and _OnceBorrowAvailable[C]:
        """Inspect the whole pipeline value once and continue with it unchanged."""
        var inspect = _ObserveOnce[Self.Value, C, False](function^)
        return Self(inspect^.call_once(self.value^))

    def then[R: Movable & Deinitable, A: Movable & Deinitable, //, F: def(var A) -> R](deinit self, function: F) -> Piped[R] where A == Self.Value:
        """Apply a pure stage and continue the chain with its result.

        Parameters:
            R: The stage's result type.
            A: The callback input type, equal to the carried value type.
            F: The stage's type: a plain function or a closure.

        Args:
            function: The stage, borrowed; it runs once, now.

        Returns:
            The chain, holding the stage's result.
        """
        return Piped[R](pipe(rebind_var[A](self.value^), function))

    def then[R: Movable & Deinitable, A: Movable & Deinitable, //, E: AnyType, F: def(var A) raises E -> R](
        deinit self, function: F
    ) raises E -> Piped[R] where A == Self.Value:
        """Apply a raising stage; its error stops the chain with its own type.

        Limitations:
            Generic code that forwards a raising callback states its error,
            `then[E=X](f)`; Mojo 1.1 cannot infer it from a forwarded callback.

        Parameters:
            R: The stage's result type.
            A: The callback input type, equal to the carried value type.
            E: The stage's error type.
            F: The stage's type: a plain function or a closure that raises `E`.

        Args:
            function: The stage, borrowed; it runs once, now.

        Returns:
            The chain, holding the stage's result.

        Raises:
            The stage's error, unchanged; later stages do not run.
        """
        # Forwarded through `pipe`, the error would be the callback's `F.E`, which
        # Mojo 1.1 cannot prove equal to `E`; the native call is the same one.
        return Piped[R](function(rebind_var[A](self.value^)))

    def then[F: Unary](deinit self, function: F) raises F.Error -> Piped[F.Out] where F.Arg == Self.Value:
        """Apply a library `Unary` value, such as a partial or a composition."""
        return Piped[F.Out](pipe(self.value^, function))

    # Explicit families use the existing public Functor contract. Native
    # callbacks are borrowed; owned library callback values are consumed.
    def map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //,
            I: Functor, F: _Unary[A, R]](
        deinit self, ref[o] function: F
    ) raises I.MapError[Self.Value, _ErrorProbe[A, R, Never]] -> Piped[I.Mapped[Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]]] where I.Element[Self.Value] == A and _MapCompatible[I, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]]:
        """Map through an explicit family, including third-party containers.

        `map[I](f)` delegates to `fp.algebra.map[I]`. The family determines the
        result container, evaluation and error types. Native callbacks are
        borrowed; deferred families retain that borrow. Use `as_unary(f^)` to
        transfer a callback into a deferred result. With no explicit family,
        supported native containers map immediately and preserve their kind;
        dictionaries map values, preserving keys, order and hasher.

        Limitations:
            Generic native callback forwarding names the family explicitly,
            and a raising callback names its error with `E=`. Automatic mapping
            supports List, Array, Deque, LinkedList, Dict, StringDict, Optional
            and Result. Other carriers require an explicit family. Filtering
            also preserves containers that can represent rejection.

        Parameters:
            A: The input payload type, including its origins.
            R: The output payload type, including its origins.
            o: The native callback's borrow origin.
            I: The Functor family that supplies mapping semantics.
            F: The native callback's concrete type.

        Args:
            function: The callback, borrowed for this operation.

        Returns:
            A pipeline holding the family's mapped carrier.

        Raises:
            The family's exact mapping error. Built-in containers propagate
            the callback error and destroy partial results on failure.
        """
        return Piped(_map_native[Self.Value, A, R, Never, I, F, False, o](function, self.value^))

    def map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //,
            I: Functor, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](
        deinit self, ref[o] function: F
    ) raises I.MapError[Self.Value, _ErrorProbe[A, R, E]] -> Piped[I.Mapped[Self.Value, _NativeUnaryRef[A, R, E, F, True, o]]] where I.Element[Self.Value] == A and _MapCompatible[I, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]]:
        """Map a raising native callback through an explicit family."""
        return Piped(_map_native[Self.Value, A, R, E, I, F, True, o](function, self.value^))

    def map[F: _UnaryViewable, o: ImmOrigin, //, I: Functor](
        deinit self, ref[o] function: F
    ) raises I.MapError[Self.Value, F._View[o]] -> Piped[I.Mapped[Self.Value, F._View[o]]] where I.Element[Self.Value] == F._View[o].Arg and _MapCompatible[I, Self.Value, F._View[o]]:
        """Map a borrowed callable view through an explicit family."""
        return Piped(_family_map[I](function._unary_view(), self.value^))

    def map[F: UnaryContract & Movable & Deinitable, //, I: Functor](
        deinit self, var function: F
    ) raises I.MapError[Self.Value, F] -> Piped[I.Mapped[Self.Value, F]] where I.Element[Self.Value] == F.Arg and _MapCompatible[I, Self.Value, F]:
        """Map an owned library callback through an explicit family."""
        return Piped(_family_map[I](function^, self.value^))

    def filter[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //,
               I: Filterable, F: _Borrowing[P, R]](
        deinit self, ref[o] predicate: F
    ) raises I.FilterError[Self.Value, _NativeBorrowRef[P, Bool, Never, F, False, o]] -> Piped[I.Filtered[Self.Value, _NativeBorrowRef[P, Bool, Never, F, False, o]]] where I.Element[Self.Value] == P and R == Bool:
        """Retain accepted payloads through a Filterable family.

        Without an explicit family, List, Deque, LinkedList, Dict, StringDict
        and Optional filter immediately and keep their concrete type. Dictionary
        predicates borrow values; keys, insertion order and hasher are preserved.
        Accepted payloads move unchanged, rejected payloads are destroyed, and
        empty inputs skip the predicate. Native callbacks are borrowed; library
        repeatable borrowing callbacks are consumed. Each predicate only borrows its input.

        Custom containers implement Filterable and use `filter[I](predicate)`.
        Deferred families retain their own evaluation and error semantics and may
        retain a native callback's borrow. Array cannot shrink while keeping its
        type; Result needs an explicit error for rejection. Neither has an
        automatic filter. Use `iterated` for lazy iterable filtering.

        Parameters:
            P: The predicate's input type, including origins.
            R: The predicate's result type; must be Bool.
            o: The native callback's borrow origin.
            I: The family that supplies filtering semantics.
            F: The native callback's concrete type.

        Args:
            predicate: The borrowing Bool predicate.

        Returns:
            A pipeline holding the family's filtered carrier.

        Raises:
            The family's exact filtering error. Native containers destroy
            remaining input and partial output on predicate failure.
        """
        return Piped(_filter_native[Self.Value, P, Never, I, F, False, o](predicate, self.value^))

    def filter[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //,
               I: Filterable, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](
        deinit self, ref[o] predicate: F
    ) raises I.FilterError[Self.Value, _NativeBorrowRef[P, Bool, E, F, True, o]] -> Piped[I.Filtered[Self.Value, _NativeBorrowRef[P, Bool, E, F, True, o]]] where I.Element[Self.Value] == P and R == Bool:
        """Filter with a raising native callback; generic forwarding names E."""
        return Piped(_filter_native[Self.Value, P, E, I, F, True, o](predicate, self.value^))

    def filter[C: _BorrowViewable, o: ImmOrigin, //, I: Filterable](deinit self, ref[o] predicate: C
    ) raises I.FilterError[Self.Value, C._BorrowView[o]] -> Piped[I.Filtered[Self.Value, C._BorrowView[o]]] where I.Element[Self.Value] == C._BorrowView[o].Payload and C._BorrowView[o].Result == Bool:
        """Filter through the selected family with a shared predicate."""
        return Piped(_family_filter[I](predicate._borrow_view(), self.value^))

    def filter[C: BorrowCallContract & Movable & Deinitable, //, I: Filterable](deinit self, var predicate: C
    ) raises I.FilterError[Self.Value, C] -> Piped[I.Filtered[Self.Value, C]] where I.Element[Self.Value] == C.Payload and C.Result == Bool and RepeatableBorrow[C]:
        """Filter through an explicit family with an owned library predicate."""
        return Piped(_family_filter[I](predicate^, self.value^))

    def filter_not[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //,
                   I: Filterable, F: _Borrowing[P, R]](
        deinit self, ref[o] predicate: F
    ) raises I.FilterError[Self.Value, _Negated[_NativeBorrowRef[P, Bool, Never, F, False, o]]] -> Piped[I.Filtered[Self.Value, _Negated[_NativeBorrowRef[P, Bool, Never, F, False, o]]]] where I.Element[Self.Value] == P and R == Bool:
        """Retain payloads the predicate rejects, preserving the container.

        Automatic calls support the same six containers as filter and run
        immediately. Each candidate is borrowed once; retained values move
        unchanged. Dictionaries test values and keep keys, order and hasher.
        Native callbacks are borrowed; library BorrowCallable values move.
        Empty inputs skip the predicate. Failure stops traversal and destroys
        partial output and remaining input, preserving the predicate's error.

        Custom containers use `filter_not[I](predicate)` with their Filterable
        family, including its deferred evaluation and associated result/error
        types. Keep a borrowed native callback alive and unmoved for as long
        as a deferred result uses it. Generic raising forwarding names E=E.

        Parameters:
            P: The predicate's input type, including origins.
            R: The predicate's result type; must be Bool.
            o: The native callback's borrow origin.
            I: The family that supplies filtering semantics.
            F: The native callback's concrete type.

        Args:
            predicate: The borrowing Bool predicate.

        Returns:
            A pipeline holding the family's carrier of rejected payloads.

        Raises:
            The family's exact error for filtering with the adapted predicate.
        """
        return Piped(_filter_native[Self.Value, P, Never, I, F, False, o, True](predicate, self.value^))

    def filter_not[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //,
                   I: Filterable, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](
        deinit self, ref[o] predicate: F
    ) raises I.FilterError[Self.Value, _Negated[_NativeBorrowRef[P, Bool, E, F, True, o]]] -> Piped[I.Filtered[Self.Value, _Negated[_NativeBorrowRef[P, Bool, E, F, True, o]]]] where I.Element[Self.Value] == P and R == Bool:
        """Retain rejected payloads with a raising native predicate; forward E explicitly."""
        return Piped(_filter_native[Self.Value, P, E, I, F, True, o, True](predicate, self.value^))

    def filter_not[C: _BorrowViewable, o: ImmOrigin, //, I: Filterable](deinit self, ref[o] predicate: C
    ) raises I.FilterError[Self.Value, _Negated[C._BorrowView[o]]] -> Piped[I.Filtered[Self.Value, _Negated[C._BorrowView[o]]]] where I.Element[Self.Value] == C._BorrowView[o].Payload and C._BorrowView[o].Result == Bool:
        """Filter through the selected family with a shared predicate."""
        return Piped(_family_filter_not[I](predicate._borrow_view(), self.value^))

    def filter_not[C: BorrowCallContract & Movable & Deinitable, //, I: Filterable](deinit self, var predicate: C
    ) raises I.FilterError[Self.Value, _Negated[C]] -> Piped[I.Filtered[Self.Value, _Negated[C]]] where I.Element[Self.Value] == C.Payload and C.Result == Bool and RepeatableBorrow[C]:
        """Retain rejected payloads through an explicit family with an owned predicate."""
        return Piped(_family_filter_not[I](predicate^, self.value^))

    # --- effect syntax (generated) ---
    # Generated by scripts/generate_effect_syntax.py; execution lives in algebra._effect_combinators.

    def fold_effect[F: BinaryContract & Movable & Deinitable, //, G: Monad, Z: AnyType = _InferError](deinit self, var function: F, var initial: F.First) raises _EntryError[Z, FoldContract[G, Self.Value, F].Error] -> Piped[FoldContract[G, Self.Value, F].Out] where FoldContract[G, Self.Value, F].Compatible and _ErrorCompatible[_EntryError[Z, FoldContract[G, Self.Value, F].Error], FoldContract[G, Self.Value, F].Error]:
        """Fold in order with an effectful accumulator step; empty input returns the initial value in the effect.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            G: The target Monad family; it determines dependent sequencing and failure.
            Z: The exact construction error for generic fold forwarding; checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.
            initial: The initial accumulator, consumed.

        Returns:
            The target effect containing the final accumulator; empty input lifts the initial value.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_fold_effect[G, Self.Value, F, _AllLive[F.First], _EntryError[Z, FoldContract[G, Self.Value, F].Error]](function^, initial^, self.value^))

    def fold_effect[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad, F: _Binary[A, B, R], Z: AnyType = _InferError](deinit self, ref[o] function: F, var initial: A) raises _EntryError[Z, FoldContract[G, Self.Value, _NativeBinaryRef[A, B, R, Never, F, False, o]].Error] -> Piped[FoldContract[G, Self.Value, _NativeBinaryRef[A, B, R, Never, F, False, o]].Out] where FoldContract[G, Self.Value, _NativeBinaryRef[A, B, R, Never, F, False, o]].Compatible and _ErrorCompatible[_EntryError[Z, FoldContract[G, Self.Value, _NativeBinaryRef[A, B, R, Never, F, False, o]].Error], FoldContract[G, Self.Value, _NativeBinaryRef[A, B, R, Never, F, False, o]].Error]:
        """Fold in order with an effectful accumulator step; empty input returns the initial value in the effect."""
        return Piped(_fold_effect[G, Self.Value, _NativeBinaryRef[A, B, R, Never, F, False, o], _AllLive[A], _EntryError[Z, FoldContract[G, Self.Value, _NativeBinaryRef[A, B, R, Never, F, False, o]].Error]](_NativeBinaryRef[A, B, R, Never, F, False, o](Pointer(to=function)), initial^, self.value^))

    def fold_effect[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad, X: Movable & Deinitable, F: _RaisingBinary[A, B, R, X], Z: AnyType = _InferError](deinit self, ref[o] function: F, var initial: A) raises _EntryError[Z, FoldContract[G, Self.Value, _NativeBinaryRef[A, B, R, X, F, True, o]].Error] -> Piped[FoldContract[G, Self.Value, _NativeBinaryRef[A, B, R, X, F, True, o]].Out] where FoldContract[G, Self.Value, _NativeBinaryRef[A, B, R, X, F, True, o]].Compatible and _ErrorCompatible[_EntryError[Z, FoldContract[G, Self.Value, _NativeBinaryRef[A, B, R, X, F, True, o]].Error], FoldContract[G, Self.Value, _NativeBinaryRef[A, B, R, X, F, True, o]].Error]:
        """Fold in order with an effectful accumulator step; empty input returns the initial value in the effect."""
        return Piped(_fold_effect[G, Self.Value, _NativeBinaryRef[A, B, R, X, F, True, o], _AllLive[A], _EntryError[Z, FoldContract[G, Self.Value, _NativeBinaryRef[A, B, R, X, F, True, o]].Error]](_NativeBinaryRef[A, B, R, X, F, True, o](Pointer(to=function)), initial^, self.value^))

    def any_effect[C: BorrowCallable, //, G: Monad, X: AnyType = _InferError](deinit self, var function: C) raises _EntryError[X, AnyContract[G, Self.Value, C].Error] -> Piped[AnyContract[G, Self.Value, C].Out] where AnyContract[G, Self.Value, C].Compatible and _ErrorCompatible[_EntryError[X, AnyContract[G, Self.Value, C].Error], AnyContract[G, Self.Value, C].Error]:
        """Test elements with an effectful borrowing predicate, stopping each branch at its decisive Bool result.

        Parameters:
            C: The borrowing library callback type.
            G: The target Monad family; it determines dependent sequencing and failure.
            X: The exact construction error for generic forwarding; checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect of Bool, stopping each branch at True; empty input lifts False.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_fold_effect[G, Self.Value, _PredicateStep[C], _BoolLive[False], _EntryError[X, AnyContract[G, Self.Value, C].Error]](_PredicateStep[C](function^), False, self.value^))

    def any_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad, F: _Borrowing[P, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, AnyContract[G, Self.Value, _NativeBorrowRef[P, R, Never, F, False, o]].Error] -> Piped[AnyContract[G, Self.Value, _NativeBorrowRef[P, R, Never, F, False, o]].Out] where AnyContract[G, Self.Value, _NativeBorrowRef[P, R, Never, F, False, o]].Compatible and _ErrorCompatible[_EntryError[X, AnyContract[G, Self.Value, _NativeBorrowRef[P, R, Never, F, False, o]].Error], AnyContract[G, Self.Value, _NativeBorrowRef[P, R, Never, F, False, o]].Error]:
        """Test elements with an effectful borrowing predicate, stopping each branch at its decisive Bool result."""
        return Piped(_fold_effect[G, Self.Value, _PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]], _BoolLive[False], _EntryError[X, AnyContract[G, Self.Value, _NativeBorrowRef[P, R, Never, F, False, o]].Error]](_PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), False, self.value^))

    def any_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, AnyContract[G, Self.Value, _NativeBorrowRef[P, R, E, F, True, o]].Error] -> Piped[AnyContract[G, Self.Value, _NativeBorrowRef[P, R, E, F, True, o]].Out] where AnyContract[G, Self.Value, _NativeBorrowRef[P, R, E, F, True, o]].Compatible and _ErrorCompatible[_EntryError[X, AnyContract[G, Self.Value, _NativeBorrowRef[P, R, E, F, True, o]].Error], AnyContract[G, Self.Value, _NativeBorrowRef[P, R, E, F, True, o]].Error]:
        """Test elements with an effectful borrowing predicate, stopping each branch at its decisive Bool result."""
        return Piped(_fold_effect[G, Self.Value, _PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]], _BoolLive[False], _EntryError[X, AnyContract[G, Self.Value, _NativeBorrowRef[P, R, E, F, True, o]].Error]](_PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), False, self.value^))

    def all_effect[C: BorrowCallable, //, G: Monad, X: AnyType = _InferError](deinit self, var function: C) raises _EntryError[X, AllContract[G, Self.Value, C].Error] -> Piped[AllContract[G, Self.Value, C].Out] where AllContract[G, Self.Value, C].Compatible and _ErrorCompatible[_EntryError[X, AllContract[G, Self.Value, C].Error], AllContract[G, Self.Value, C].Error]:
        """Test elements with an effectful borrowing predicate, stopping each branch at its decisive Bool result.

        Parameters:
            C: The borrowing library callback type.
            G: The target Monad family; it determines dependent sequencing and failure.
            X: The exact construction error for generic forwarding; checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect of Bool, stopping each branch at False; empty input lifts True.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_fold_effect[G, Self.Value, _PredicateStep[C], _BoolLive[True], _EntryError[X, AllContract[G, Self.Value, C].Error]](_PredicateStep[C](function^), True, self.value^))

    def all_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad, F: _Borrowing[P, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, AllContract[G, Self.Value, _NativeBorrowRef[P, R, Never, F, False, o]].Error] -> Piped[AllContract[G, Self.Value, _NativeBorrowRef[P, R, Never, F, False, o]].Out] where AllContract[G, Self.Value, _NativeBorrowRef[P, R, Never, F, False, o]].Compatible and _ErrorCompatible[_EntryError[X, AllContract[G, Self.Value, _NativeBorrowRef[P, R, Never, F, False, o]].Error], AllContract[G, Self.Value, _NativeBorrowRef[P, R, Never, F, False, o]].Error]:
        """Test elements with an effectful borrowing predicate, stopping each branch at its decisive Bool result."""
        return Piped(_fold_effect[G, Self.Value, _PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]], _BoolLive[True], _EntryError[X, AllContract[G, Self.Value, _NativeBorrowRef[P, R, Never, F, False, o]].Error]](_PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), True, self.value^))

    def all_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, AllContract[G, Self.Value, _NativeBorrowRef[P, R, E, F, True, o]].Error] -> Piped[AllContract[G, Self.Value, _NativeBorrowRef[P, R, E, F, True, o]].Out] where AllContract[G, Self.Value, _NativeBorrowRef[P, R, E, F, True, o]].Compatible and _ErrorCompatible[_EntryError[X, AllContract[G, Self.Value, _NativeBorrowRef[P, R, E, F, True, o]].Error], AllContract[G, Self.Value, _NativeBorrowRef[P, R, E, F, True, o]].Error]:
        """Test elements with an effectful borrowing predicate, stopping each branch at its decisive Bool result."""
        return Piped(_fold_effect[G, Self.Value, _PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]], _BoolLive[True], _EntryError[X, AllContract[G, Self.Value, _NativeBorrowRef[P, R, E, F, True, o]].Error]](_PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), True, self.value^))

    def find_effect[C: BorrowCallable, //, G: Monad, X: AnyType = _InferError](deinit self, var function: C) raises _EntryError[X, FindContract[G, Self.Value, C].Error] -> Piped[FindContract[G, Self.Value, C].Out] where FindContract[G, Self.Value, C].Compatible and (_ErrorCompatible[_EntryError[X, FindContract[G, Self.Value, C].Error], C.Failure] or _ErrorCompatible[_EntryError[X, FindContract[G, Self.Value, C].Error], FindContract[G, Self.Value, C].Error]):
        """Find the first original element selected by an effectful borrowing predicate in each live branch.

        Parameters:
            C: The borrowing library callback type.
            G: The target Monad family; it determines dependent sequencing and failure.
            X: The exact construction error for generic forwarding; checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect of Optional, stopping each live branch at its first accepted original element; empty input lifts None.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_fold_effect[G, Self.Value, _SearchStep[downcast[C.Payload, Movable & Deinitable], _EffectRetain[downcast[C.Payload, Movable & Deinitable], G, C, True]], _FirstPresent[downcast[C.Payload, Movable & Deinitable]], _EntryError[X, FindContract[G, Self.Value, C].Error]](_SearchStep[downcast[C.Payload, Movable & Deinitable], _EffectRetain[downcast[C.Payload, Movable & Deinitable], G, C, True]](_EffectRetain[downcast[C.Payload, Movable & Deinitable], G, C, True](function^)), Optional[downcast[C.Payload, Movable & Deinitable]](), self.value^))

    def find_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad, F: _Borrowing[P, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, FindContract[G, Self.Value, _NativeBorrowRef[P, R, Never, F, False, o]].Error] -> Piped[FindContract[G, Self.Value, _NativeBorrowRef[P, R, Never, F, False, o]].Out] where FindContract[G, Self.Value, _NativeBorrowRef[P, R, Never, F, False, o]].Compatible and (_ErrorCompatible[_EntryError[X, FindContract[G, Self.Value, _NativeBorrowRef[P, R, Never, F, False, o]].Error], Never] or _ErrorCompatible[_EntryError[X, FindContract[G, Self.Value, _NativeBorrowRef[P, R, Never, F, False, o]].Error], FindContract[G, Self.Value, _NativeBorrowRef[P, R, Never, F, False, o]].Error]):
        """Find the first original element selected by an effectful borrowing predicate in each live branch."""
        return Piped(_fold_effect[G, Self.Value, _SearchStep[downcast[P, Movable & Deinitable], _EffectRetain[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _FirstPresent[downcast[P, Movable & Deinitable]], _EntryError[X, FindContract[G, Self.Value, _NativeBorrowRef[P, R, Never, F, False, o]].Error]](_SearchStep[downcast[P, Movable & Deinitable], _EffectRetain[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]](_EffectRetain[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function)))), Optional[downcast[P, Movable & Deinitable]](), self.value^))

    def find_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, FindContract[G, Self.Value, _NativeBorrowRef[P, R, E, F, True, o]].Error] -> Piped[FindContract[G, Self.Value, _NativeBorrowRef[P, R, E, F, True, o]].Out] where FindContract[G, Self.Value, _NativeBorrowRef[P, R, E, F, True, o]].Compatible and (_ErrorCompatible[_EntryError[X, FindContract[G, Self.Value, _NativeBorrowRef[P, R, E, F, True, o]].Error], E] or _ErrorCompatible[_EntryError[X, FindContract[G, Self.Value, _NativeBorrowRef[P, R, E, F, True, o]].Error], FindContract[G, Self.Value, _NativeBorrowRef[P, R, E, F, True, o]].Error]):
        """Find the first original element selected by an effectful borrowing predicate in each live branch."""
        return Piped(_fold_effect[G, Self.Value, _SearchStep[downcast[P, Movable & Deinitable], _EffectRetain[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _FirstPresent[downcast[P, Movable & Deinitable]], _EntryError[X, FindContract[G, Self.Value, _NativeBorrowRef[P, R, E, F, True, o]].Error]](_SearchStep[downcast[P, Movable & Deinitable], _EffectRetain[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]](_EffectRetain[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function)))), Optional[downcast[P, Movable & Deinitable]](), self.value^))

    def find_map_effect[F: UnaryContract & Movable & Deinitable, //, G: Monad, X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, FindMapContract[G, Self.Value, F].Error] -> Piped[FindMapContract[G, Self.Value, F].Out] where FindMapContract[G, Self.Value, F].Compatible and (_ErrorCompatible[_EntryError[X, FindMapContract[G, Self.Value, F].Error], F.Error] or _ErrorCompatible[_EntryError[X, FindMapContract[G, Self.Value, F].Error], FindMapContract[G, Self.Value, F].Error]):
        """Find the first present Optional produced inside the selected Monad in each live branch.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            G: The target Monad family; it determines dependent sequencing and failure.
            X: The exact construction error for generic forwarding; checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect of the first present Optional in each live branch; empty input lifts None and target failure stays in the effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_fold_effect[G, Self.Value, _SearchStep[_ListElement[G.Element[F.Out]], F], _FirstPresent[_ListElement[G.Element[F.Out]]], _EntryError[X, FindMapContract[G, Self.Value, F].Error]](_SearchStep[_ListElement[G.Element[F.Out]], F](function^), Optional[_ListElement[G.Element[F.Out]]](), self.value^))

    def find_map_effect[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad, F: _Unary[A, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, FindMapContract[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]].Error] -> Piped[FindMapContract[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]].Out] where FindMapContract[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]].Compatible and (_ErrorCompatible[_EntryError[X, FindMapContract[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]].Error], Never] or _ErrorCompatible[_EntryError[X, FindMapContract[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]].Error], FindMapContract[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]].Error]):
        """Find the first present Optional produced inside the selected Monad in each live branch."""
        return Piped(_fold_effect[G, Self.Value, _SearchStep[_ListElement[G.Element[R]], _NativeUnaryRef[A, R, Never, F, False, o]], _FirstPresent[_ListElement[G.Element[R]]], _EntryError[X, FindMapContract[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]].Error]](_SearchStep[_ListElement[G.Element[R]], _NativeUnaryRef[A, R, Never, F, False, o]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), Optional[_ListElement[G.Element[R]]](), self.value^))

    def find_map_effect[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, FindMapContract[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]].Error] -> Piped[FindMapContract[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]].Out] where FindMapContract[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]].Compatible and (_ErrorCompatible[_EntryError[X, FindMapContract[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]].Error], E] or _ErrorCompatible[_EntryError[X, FindMapContract[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]].Error], FindMapContract[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]].Error]):
        """Find the first present Optional produced inside the selected Monad in each live branch."""
        return Piped(_fold_effect[G, Self.Value, _SearchStep[_ListElement[G.Element[R]], _NativeUnaryRef[A, R, E, F, True, o]], _FirstPresent[_ListElement[G.Element[R]]], _EntryError[X, FindMapContract[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]].Error]](_SearchStep[_ListElement[G.Element[R]], _NativeUnaryRef[A, R, E, F, True, o]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), Optional[_ListElement[G.Element[R]]](), self.value^))

    def fold_map_effect[F: UnaryContract & Movable & Deinitable, //, G: Monad, M: Monoid, X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, FoldMapContract[G, M, Self.Value, F].Error] -> Piped[FoldMapContract[G, M, Self.Value, F].Out] where FoldMapContract[G, M, Self.Value, F].Compatible and (_ErrorCompatible[_EntryError[X, FoldMapContract[G, M, Self.Value, F].Error], F.Error] or _ErrorCompatible[_EntryError[X, FoldMapContract[G, M, Self.Value, F].Error], FoldMapContract[G, M, Self.Value, F].Error]) and _ErrorCompatible[_EntryError[X, FoldMapContract[G, M, Self.Value, F].Error], M.Error]:
        """Map each element into the selected Monad and combine its values in order with an explicit Monoid.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            G: The target Monad family; it determines dependent sequencing and failure.
            M: The Monoid providing the result type, identity and ordered combination.
            X: The exact construction error for generic forwarding; checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect of ordered monoid combination. Identity is constructed before source binding, including for deferred targets; callbacks and combinations follow the target timing.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_fold_map_effect[G, M, Self.Value, F, _EntryError[X, FoldMapContract[G, M, Self.Value, F].Error]](function^, self.value^))

    def fold_map_effect[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad, M: Monoid, F: _Unary[A, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, FoldMapContract[G, M, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]].Error] -> Piped[FoldMapContract[G, M, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]].Out] where FoldMapContract[G, M, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]].Compatible and (_ErrorCompatible[_EntryError[X, FoldMapContract[G, M, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]].Error], Never] or _ErrorCompatible[_EntryError[X, FoldMapContract[G, M, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]].Error], FoldMapContract[G, M, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]].Error]) and _ErrorCompatible[_EntryError[X, FoldMapContract[G, M, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]].Error], M.Error]:
        """Map each element into the selected Monad and combine its values in order with an explicit Monoid."""
        return Piped(_fold_map_effect[G, M, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o], _EntryError[X, FoldMapContract[G, M, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]].Error]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), self.value^))

    def fold_map_effect[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Monad, M: Monoid, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, FoldMapContract[G, M, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]].Error] -> Piped[FoldMapContract[G, M, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]].Out] where FoldMapContract[G, M, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]].Compatible and (_ErrorCompatible[_EntryError[X, FoldMapContract[G, M, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]].Error], E] or _ErrorCompatible[_EntryError[X, FoldMapContract[G, M, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]].Error], FoldMapContract[G, M, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]].Error]) and _ErrorCompatible[_EntryError[X, FoldMapContract[G, M, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]].Error], M.Error]:
        """Map each element into the selected Monad and combine its values in order with an explicit Monoid."""
        return Piped(_fold_map_effect[G, M, Self.Value, _NativeUnaryRef[A, R, E, F, True, o], _EntryError[X, FoldMapContract[G, M, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]].Error]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self.value^))

    def fold_effect[F: BinaryContract & Movable & Deinitable, N: Int, //, G: Monad, Z: AnyType = _InferError](deinit self, var function: F, var initial: F.First) raises _EntryError[Z, FoldContract[G, List[F.Second], F].Error] -> Piped[FoldContract[G, List[F.Second], F].Out] where Self.Value == Array[F.Second, N] and FoldContract[G, List[F.Second], F].Compatible and _ErrorCompatible[_EntryError[Z, FoldContract[G, List[F.Second], F].Error], FoldContract[G, List[F.Second], F].Error]:
        """Fold in order with an effectful accumulator step; empty input returns the initial value in the effect.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            N: The native array length; the source moves through temporary List storage.
            G: The target Monad family; it determines dependent sequencing and failure.
            Z: The exact construction error for generic fold forwarding; checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.
            initial: The initial accumulator, consumed.

        Returns:
            The target effect containing the final accumulator; empty input lifts the initial value.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_fold_effect[G, List[F.Second], F, _AllLive[F.First], _EntryError[Z, FoldContract[G, List[F.Second], F].Error]](function^, initial^, _take_array(rebind_var[Array[F.Second, N]](self.value^))))

    def fold_effect[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, G: Monad, F: _Binary[A, B, R], Z: AnyType = _InferError](deinit self, ref[o] function: F, var initial: A) raises _EntryError[Z, FoldContract[G, List[B], _NativeBinaryRef[A, B, R, Never, F, False, o]].Error] -> Piped[FoldContract[G, List[B], _NativeBinaryRef[A, B, R, Never, F, False, o]].Out] where Self.Value == Array[B, N] and FoldContract[G, List[B], _NativeBinaryRef[A, B, R, Never, F, False, o]].Compatible and _ErrorCompatible[_EntryError[Z, FoldContract[G, List[B], _NativeBinaryRef[A, B, R, Never, F, False, o]].Error], FoldContract[G, List[B], _NativeBinaryRef[A, B, R, Never, F, False, o]].Error]:
        """Fold in order with an effectful accumulator step; empty input returns the initial value in the effect."""
        return Piped(_fold_effect[G, List[B], _NativeBinaryRef[A, B, R, Never, F, False, o], _AllLive[A], _EntryError[Z, FoldContract[G, List[B], _NativeBinaryRef[A, B, R, Never, F, False, o]].Error]](_NativeBinaryRef[A, B, R, Never, F, False, o](Pointer(to=function)), initial^, _take_array(rebind_var[Array[B, N]](self.value^))))

    def fold_effect[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, G: Monad, X: Movable & Deinitable, F: _RaisingBinary[A, B, R, X], Z: AnyType = _InferError](deinit self, ref[o] function: F, var initial: A) raises _EntryError[Z, FoldContract[G, List[B], _NativeBinaryRef[A, B, R, X, F, True, o]].Error] -> Piped[FoldContract[G, List[B], _NativeBinaryRef[A, B, R, X, F, True, o]].Out] where Self.Value == Array[B, N] and FoldContract[G, List[B], _NativeBinaryRef[A, B, R, X, F, True, o]].Compatible and _ErrorCompatible[_EntryError[Z, FoldContract[G, List[B], _NativeBinaryRef[A, B, R, X, F, True, o]].Error], FoldContract[G, List[B], _NativeBinaryRef[A, B, R, X, F, True, o]].Error]:
        """Fold in order with an effectful accumulator step; empty input returns the initial value in the effect."""
        return Piped(_fold_effect[G, List[B], _NativeBinaryRef[A, B, R, X, F, True, o], _AllLive[A], _EntryError[Z, FoldContract[G, List[B], _NativeBinaryRef[A, B, R, X, F, True, o]].Error]](_NativeBinaryRef[A, B, R, X, F, True, o](Pointer(to=function)), initial^, _take_array(rebind_var[Array[B, N]](self.value^))))

    def any_effect[C: BorrowCallable, N: Int, //, G: Monad, X: AnyType = _InferError](deinit self, var function: C) raises _EntryError[X, AnyContract[G, List[downcast[C.Payload, Movable & Deinitable]], C].Error] -> Piped[AnyContract[G, List[downcast[C.Payload, Movable & Deinitable]], C].Out] where Self.Value == Array[downcast[C.Payload, Movable & Deinitable], N] and AnyContract[G, List[downcast[C.Payload, Movable & Deinitable]], C].Compatible and _ErrorCompatible[_EntryError[X, AnyContract[G, List[downcast[C.Payload, Movable & Deinitable]], C].Error], AnyContract[G, List[downcast[C.Payload, Movable & Deinitable]], C].Error]:
        """Test elements with an effectful borrowing predicate, stopping each branch at its decisive Bool result.

        Parameters:
            C: The borrowing library callback type.
            N: The native array length; the source moves through temporary List storage.
            G: The target Monad family; it determines dependent sequencing and failure.
            X: The exact construction error for generic forwarding; checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect of Bool, stopping each branch at True; empty input lifts False.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_fold_effect[G, List[downcast[C.Payload, Movable & Deinitable]], _PredicateStep[C], _BoolLive[False], _EntryError[X, AnyContract[G, List[downcast[C.Payload, Movable & Deinitable]], C].Error]](_PredicateStep[C](function^), False, _take_array(rebind_var[Array[downcast[C.Payload, Movable & Deinitable], N]](self.value^))))

    def any_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, G: Monad, F: _Borrowing[P, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, AnyContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, Never, F, False, o]].Error] -> Piped[AnyContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, Never, F, False, o]].Out] where Self.Value == Array[downcast[P, Movable & Deinitable], N] and AnyContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, Never, F, False, o]].Compatible and _ErrorCompatible[_EntryError[X, AnyContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, Never, F, False, o]].Error], AnyContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, Never, F, False, o]].Error]:
        """Test elements with an effectful borrowing predicate, stopping each branch at its decisive Bool result."""
        return Piped(_fold_effect[G, List[downcast[P, Movable & Deinitable]], _PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]], _BoolLive[False], _EntryError[X, AnyContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, Never, F, False, o]].Error]](_PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), False, _take_array(rebind_var[Array[downcast[P, Movable & Deinitable], N]](self.value^))))

    def any_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, G: Monad, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, AnyContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, E, F, True, o]].Error] -> Piped[AnyContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, E, F, True, o]].Out] where Self.Value == Array[downcast[P, Movable & Deinitable], N] and AnyContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, E, F, True, o]].Compatible and _ErrorCompatible[_EntryError[X, AnyContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, E, F, True, o]].Error], AnyContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, E, F, True, o]].Error]:
        """Test elements with an effectful borrowing predicate, stopping each branch at its decisive Bool result."""
        return Piped(_fold_effect[G, List[downcast[P, Movable & Deinitable]], _PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]], _BoolLive[False], _EntryError[X, AnyContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, E, F, True, o]].Error]](_PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), False, _take_array(rebind_var[Array[downcast[P, Movable & Deinitable], N]](self.value^))))

    def all_effect[C: BorrowCallable, N: Int, //, G: Monad, X: AnyType = _InferError](deinit self, var function: C) raises _EntryError[X, AllContract[G, List[downcast[C.Payload, Movable & Deinitable]], C].Error] -> Piped[AllContract[G, List[downcast[C.Payload, Movable & Deinitable]], C].Out] where Self.Value == Array[downcast[C.Payload, Movable & Deinitable], N] and AllContract[G, List[downcast[C.Payload, Movable & Deinitable]], C].Compatible and _ErrorCompatible[_EntryError[X, AllContract[G, List[downcast[C.Payload, Movable & Deinitable]], C].Error], AllContract[G, List[downcast[C.Payload, Movable & Deinitable]], C].Error]:
        """Test elements with an effectful borrowing predicate, stopping each branch at its decisive Bool result.

        Parameters:
            C: The borrowing library callback type.
            N: The native array length; the source moves through temporary List storage.
            G: The target Monad family; it determines dependent sequencing and failure.
            X: The exact construction error for generic forwarding; checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect of Bool, stopping each branch at False; empty input lifts True.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_fold_effect[G, List[downcast[C.Payload, Movable & Deinitable]], _PredicateStep[C], _BoolLive[True], _EntryError[X, AllContract[G, List[downcast[C.Payload, Movable & Deinitable]], C].Error]](_PredicateStep[C](function^), True, _take_array(rebind_var[Array[downcast[C.Payload, Movable & Deinitable], N]](self.value^))))

    def all_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, G: Monad, F: _Borrowing[P, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, AllContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, Never, F, False, o]].Error] -> Piped[AllContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, Never, F, False, o]].Out] where Self.Value == Array[downcast[P, Movable & Deinitable], N] and AllContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, Never, F, False, o]].Compatible and _ErrorCompatible[_EntryError[X, AllContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, Never, F, False, o]].Error], AllContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, Never, F, False, o]].Error]:
        """Test elements with an effectful borrowing predicate, stopping each branch at its decisive Bool result."""
        return Piped(_fold_effect[G, List[downcast[P, Movable & Deinitable]], _PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]], _BoolLive[True], _EntryError[X, AllContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, Never, F, False, o]].Error]](_PredicateStep[_NativeBorrowRef[P, R, Never, F, False, o]](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), True, _take_array(rebind_var[Array[downcast[P, Movable & Deinitable], N]](self.value^))))

    def all_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, G: Monad, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, AllContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, E, F, True, o]].Error] -> Piped[AllContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, E, F, True, o]].Out] where Self.Value == Array[downcast[P, Movable & Deinitable], N] and AllContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, E, F, True, o]].Compatible and _ErrorCompatible[_EntryError[X, AllContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, E, F, True, o]].Error], AllContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, E, F, True, o]].Error]:
        """Test elements with an effectful borrowing predicate, stopping each branch at its decisive Bool result."""
        return Piped(_fold_effect[G, List[downcast[P, Movable & Deinitable]], _PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]], _BoolLive[True], _EntryError[X, AllContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, E, F, True, o]].Error]](_PredicateStep[_NativeBorrowRef[P, R, E, F, True, o]](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), True, _take_array(rebind_var[Array[downcast[P, Movable & Deinitable], N]](self.value^))))

    def find_effect[C: BorrowCallable, N: Int, //, G: Monad, X: AnyType = _InferError](deinit self, var function: C) raises _EntryError[X, FindContract[G, List[downcast[C.Payload, Movable & Deinitable]], C].Error] -> Piped[FindContract[G, List[downcast[C.Payload, Movable & Deinitable]], C].Out] where Self.Value == Array[downcast[C.Payload, Movable & Deinitable], N] and FindContract[G, List[downcast[C.Payload, Movable & Deinitable]], C].Compatible and (_ErrorCompatible[_EntryError[X, FindContract[G, List[downcast[C.Payload, Movable & Deinitable]], C].Error], C.Failure] or _ErrorCompatible[_EntryError[X, FindContract[G, List[downcast[C.Payload, Movable & Deinitable]], C].Error], FindContract[G, List[downcast[C.Payload, Movable & Deinitable]], C].Error]):
        """Find the first original element selected by an effectful borrowing predicate in each live branch.

        Parameters:
            C: The borrowing library callback type.
            N: The native array length; the source moves through temporary List storage.
            G: The target Monad family; it determines dependent sequencing and failure.
            X: The exact construction error for generic forwarding; checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect of Optional, stopping each live branch at its first accepted original element; empty input lifts None.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_fold_effect[G, List[downcast[C.Payload, Movable & Deinitable]], _SearchStep[downcast[C.Payload, Movable & Deinitable], _EffectRetain[downcast[C.Payload, Movable & Deinitable], G, C, True]], _FirstPresent[downcast[C.Payload, Movable & Deinitable]], _EntryError[X, FindContract[G, List[downcast[C.Payload, Movable & Deinitable]], C].Error]](_SearchStep[downcast[C.Payload, Movable & Deinitable], _EffectRetain[downcast[C.Payload, Movable & Deinitable], G, C, True]](_EffectRetain[downcast[C.Payload, Movable & Deinitable], G, C, True](function^)), Optional[downcast[C.Payload, Movable & Deinitable]](), _take_array(rebind_var[Array[downcast[C.Payload, Movable & Deinitable], N]](self.value^))))

    def find_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, G: Monad, F: _Borrowing[P, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, FindContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, Never, F, False, o]].Error] -> Piped[FindContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, Never, F, False, o]].Out] where Self.Value == Array[downcast[P, Movable & Deinitable], N] and FindContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, Never, F, False, o]].Compatible and (_ErrorCompatible[_EntryError[X, FindContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, Never, F, False, o]].Error], Never] or _ErrorCompatible[_EntryError[X, FindContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, Never, F, False, o]].Error], FindContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, Never, F, False, o]].Error]):
        """Find the first original element selected by an effectful borrowing predicate in each live branch."""
        return Piped(_fold_effect[G, List[downcast[P, Movable & Deinitable]], _SearchStep[downcast[P, Movable & Deinitable], _EffectRetain[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _FirstPresent[downcast[P, Movable & Deinitable]], _EntryError[X, FindContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, Never, F, False, o]].Error]](_SearchStep[downcast[P, Movable & Deinitable], _EffectRetain[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]](_EffectRetain[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function)))), Optional[downcast[P, Movable & Deinitable]](), _take_array(rebind_var[Array[downcast[P, Movable & Deinitable], N]](self.value^))))

    def find_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, G: Monad, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, FindContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, E, F, True, o]].Error] -> Piped[FindContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, E, F, True, o]].Out] where Self.Value == Array[downcast[P, Movable & Deinitable], N] and FindContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, E, F, True, o]].Compatible and (_ErrorCompatible[_EntryError[X, FindContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, E, F, True, o]].Error], E] or _ErrorCompatible[_EntryError[X, FindContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, E, F, True, o]].Error], FindContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, E, F, True, o]].Error]):
        """Find the first original element selected by an effectful borrowing predicate in each live branch."""
        return Piped(_fold_effect[G, List[downcast[P, Movable & Deinitable]], _SearchStep[downcast[P, Movable & Deinitable], _EffectRetain[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _FirstPresent[downcast[P, Movable & Deinitable]], _EntryError[X, FindContract[G, List[downcast[P, Movable & Deinitable]], _NativeBorrowRef[P, R, E, F, True, o]].Error]](_SearchStep[downcast[P, Movable & Deinitable], _EffectRetain[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]](_EffectRetain[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function)))), Optional[downcast[P, Movable & Deinitable]](), _take_array(rebind_var[Array[downcast[P, Movable & Deinitable], N]](self.value^))))

    def find_map_effect[F: UnaryContract & Movable & Deinitable, N: Int, //, G: Monad, X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, FindMapContract[G, List[F.Arg], F].Error] -> Piped[FindMapContract[G, List[F.Arg], F].Out] where Self.Value == Array[F.Arg, N] and FindMapContract[G, List[F.Arg], F].Compatible and (_ErrorCompatible[_EntryError[X, FindMapContract[G, List[F.Arg], F].Error], F.Error] or _ErrorCompatible[_EntryError[X, FindMapContract[G, List[F.Arg], F].Error], FindMapContract[G, List[F.Arg], F].Error]):
        """Find the first present Optional produced inside the selected Monad in each live branch.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            N: The native array length; the source moves through temporary List storage.
            G: The target Monad family; it determines dependent sequencing and failure.
            X: The exact construction error for generic forwarding; checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect of the first present Optional in each live branch; empty input lifts None and target failure stays in the effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_fold_effect[G, List[F.Arg], _SearchStep[_ListElement[G.Element[F.Out]], F], _FirstPresent[_ListElement[G.Element[F.Out]]], _EntryError[X, FindMapContract[G, List[F.Arg], F].Error]](_SearchStep[_ListElement[G.Element[F.Out]], F](function^), Optional[_ListElement[G.Element[F.Out]]](), _take_array(rebind_var[Array[F.Arg, N]](self.value^))))

    def find_map_effect[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, G: Monad, F: _Unary[A, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, FindMapContract[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]].Error] -> Piped[FindMapContract[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]].Out] where Self.Value == Array[A, N] and FindMapContract[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]].Compatible and (_ErrorCompatible[_EntryError[X, FindMapContract[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]].Error], Never] or _ErrorCompatible[_EntryError[X, FindMapContract[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]].Error], FindMapContract[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]].Error]):
        """Find the first present Optional produced inside the selected Monad in each live branch."""
        return Piped(_fold_effect[G, List[A], _SearchStep[_ListElement[G.Element[R]], _NativeUnaryRef[A, R, Never, F, False, o]], _FirstPresent[_ListElement[G.Element[R]]], _EntryError[X, FindMapContract[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]].Error]](_SearchStep[_ListElement[G.Element[R]], _NativeUnaryRef[A, R, Never, F, False, o]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), Optional[_ListElement[G.Element[R]]](), _take_array(rebind_var[Array[A, N]](self.value^))))

    def find_map_effect[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, G: Monad, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, FindMapContract[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]].Error] -> Piped[FindMapContract[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]].Out] where Self.Value == Array[A, N] and FindMapContract[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]].Compatible and (_ErrorCompatible[_EntryError[X, FindMapContract[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]].Error], E] or _ErrorCompatible[_EntryError[X, FindMapContract[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]].Error], FindMapContract[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]].Error]):
        """Find the first present Optional produced inside the selected Monad in each live branch."""
        return Piped(_fold_effect[G, List[A], _SearchStep[_ListElement[G.Element[R]], _NativeUnaryRef[A, R, E, F, True, o]], _FirstPresent[_ListElement[G.Element[R]]], _EntryError[X, FindMapContract[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]].Error]](_SearchStep[_ListElement[G.Element[R]], _NativeUnaryRef[A, R, E, F, True, o]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), Optional[_ListElement[G.Element[R]]](), _take_array(rebind_var[Array[A, N]](self.value^))))

    def fold_map_effect[F: UnaryContract & Movable & Deinitable, N: Int, //, G: Monad, M: Monoid, X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, FoldMapContract[G, M, List[F.Arg], F].Error] -> Piped[FoldMapContract[G, M, List[F.Arg], F].Out] where Self.Value == Array[F.Arg, N] and FoldMapContract[G, M, List[F.Arg], F].Compatible and (_ErrorCompatible[_EntryError[X, FoldMapContract[G, M, List[F.Arg], F].Error], F.Error] or _ErrorCompatible[_EntryError[X, FoldMapContract[G, M, List[F.Arg], F].Error], FoldMapContract[G, M, List[F.Arg], F].Error]) and _ErrorCompatible[_EntryError[X, FoldMapContract[G, M, List[F.Arg], F].Error], M.Error]:
        """Map each element into the selected Monad and combine its values in order with an explicit Monoid.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            N: The native array length; the source moves through temporary List storage.
            G: The target Monad family; it determines dependent sequencing and failure.
            M: The Monoid providing the result type, identity and ordered combination.
            X: The exact construction error for generic forwarding; checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect of ordered monoid combination. Identity is constructed before source binding, including for deferred targets; callbacks and combinations follow the target timing.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_fold_map_effect[G, M, List[F.Arg], F, _EntryError[X, FoldMapContract[G, M, List[F.Arg], F].Error]](function^, _take_array(rebind_var[Array[F.Arg, N]](self.value^))))

    def fold_map_effect[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, G: Monad, M: Monoid, F: _Unary[A, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, FoldMapContract[G, M, List[A], _NativeUnaryRef[A, R, Never, F, False, o]].Error] -> Piped[FoldMapContract[G, M, List[A], _NativeUnaryRef[A, R, Never, F, False, o]].Out] where Self.Value == Array[A, N] and FoldMapContract[G, M, List[A], _NativeUnaryRef[A, R, Never, F, False, o]].Compatible and (_ErrorCompatible[_EntryError[X, FoldMapContract[G, M, List[A], _NativeUnaryRef[A, R, Never, F, False, o]].Error], Never] or _ErrorCompatible[_EntryError[X, FoldMapContract[G, M, List[A], _NativeUnaryRef[A, R, Never, F, False, o]].Error], FoldMapContract[G, M, List[A], _NativeUnaryRef[A, R, Never, F, False, o]].Error]) and _ErrorCompatible[_EntryError[X, FoldMapContract[G, M, List[A], _NativeUnaryRef[A, R, Never, F, False, o]].Error], M.Error]:
        """Map each element into the selected Monad and combine its values in order with an explicit Monoid."""
        return Piped(_fold_map_effect[G, M, List[A], _NativeUnaryRef[A, R, Never, F, False, o], _EntryError[X, FoldMapContract[G, M, List[A], _NativeUnaryRef[A, R, Never, F, False, o]].Error]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), _take_array(rebind_var[Array[A, N]](self.value^))))

    def fold_map_effect[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, G: Monad, M: Monoid, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, FoldMapContract[G, M, List[A], _NativeUnaryRef[A, R, E, F, True, o]].Error] -> Piped[FoldMapContract[G, M, List[A], _NativeUnaryRef[A, R, E, F, True, o]].Out] where Self.Value == Array[A, N] and FoldMapContract[G, M, List[A], _NativeUnaryRef[A, R, E, F, True, o]].Compatible and (_ErrorCompatible[_EntryError[X, FoldMapContract[G, M, List[A], _NativeUnaryRef[A, R, E, F, True, o]].Error], E] or _ErrorCompatible[_EntryError[X, FoldMapContract[G, M, List[A], _NativeUnaryRef[A, R, E, F, True, o]].Error], FoldMapContract[G, M, List[A], _NativeUnaryRef[A, R, E, F, True, o]].Error]) and _ErrorCompatible[_EntryError[X, FoldMapContract[G, M, List[A], _NativeUnaryRef[A, R, E, F, True, o]].Error], M.Error]:
        """Map each element into the selected Monad and combine its values in order with an explicit Monoid."""
        return Piped(_fold_map_effect[G, M, List[A], _NativeUnaryRef[A, R, E, F, True, o], _EntryError[X, FoldMapContract[G, M, List[A], _NativeUnaryRef[A, R, E, F, True, o]].Error]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), _take_array(rebind_var[Array[A, N]](self.value^))))

    def if_effect[L: ThunkContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable, //, G: Monad, X: AnyType = _InferError](deinit self, var on_true: L, var on_false: R) raises _EntryError[X, IfContract[G, Self.Value, L, R].Error] -> Piped[IfContract[G, Self.Value, L, R].Out] where IfContract[G, Self.Value, L, R].ShapeCompatible and _ErrorCompatible[_EntryError[X, IfContract[G, Self.Value, L, R].Error], IfContract[G, Self.Value, L, R].Error]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence.

        Parameters:
            L: The true-branch factory, retaining its native error and receiver mode.
            R: The false-branch factory, retaining its native error and receiver mode.
            G: The target Monad family; it determines dependent sequencing and failure.
            X: The exact construction error for generic forwarding; checked without converting errors.

        Args:
            on_true: The branch factory, consumed; invoked only for its selected Bool outcome.
            on_false: The branch factory, consumed; invoked only for its selected Bool outcome.

        Returns:
            The selected branch effect; absence or failure in the condition skips both factories.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_if_effect[G, Self.Value, L, R, _EntryError[X, IfContract[G, Self.Value, L, R].Error]](self.value^, on_true^, on_false^))

    def if_effect[L: ThunkContract & Movable & Deinitable, W: Movable & Deinitable, q: ImmOrigin, //, G: Monad, R: _Thunk[W], X: AnyType = _InferError](deinit self, var on_true: L, ref[q] on_false: R) raises _EntryError[X, G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[L.Out, W], L.Error]]] -> Piped[G.Bound[Self.Value, _IfEffect[G, L, _NativeThunkRef[W, Never, R, False, q]]]] where G.Element[Self.Value] == Bool and G.Element[L.Out] == G.Element[W] and _ErrorCompatible[_EntryError[X, G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[L.Out, W], L.Error]]], G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[L.Out, W], L.Error]]] and _CarrierCompatible[G, Self.Value] and _CarrierCompatible[G, L.Out] and _CarrierCompatible[G, W]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[G, Self.Value, L, _NativeThunkRef[W, Never, R, False, q], _EntryError[X, G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[L.Out, W], L.Error]]]](self.value^, on_true^, _NativeThunkRef[W, Never, R, False, q](Pointer(to=on_false))))

    def if_effect[L: ThunkContract & Movable & Deinitable, W: Movable & Deinitable, q: ImmOrigin, //, G: Monad, D: Movable & Deinitable, R: _RaisingThunk[W, D], X: AnyType = _InferError](deinit self, var on_true: L, ref[q] on_false: R) raises _EntryError[X, G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[L.Out, W], _CommonError[L.Error, D]]]] -> Piped[G.Bound[Self.Value, _IfEffect[G, L, _NativeThunkRef[W, D, R, True, q]]]] where G.Element[Self.Value] == Bool and G.Element[L.Out] == G.Element[W] and _ErrorCompatible[_EntryError[X, G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[L.Out, W], _CommonError[L.Error, D]]]], G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[L.Out, W], _CommonError[L.Error, D]]]] and _CarrierCompatible[G, Self.Value] and _CarrierCompatible[G, L.Out] and _CarrierCompatible[G, W]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[G, Self.Value, L, _NativeThunkRef[W, D, R, True, q], _EntryError[X, G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[L.Out, W], _CommonError[L.Error, D]]]]](self.value^, on_true^, _NativeThunkRef[W, D, R, True, q](Pointer(to=on_false))))

    def if_effect[U: Movable & Deinitable, o: ImmOrigin, R: ThunkContract & Movable & Deinitable, //, G: Monad, L: _Thunk[U], X: AnyType = _InferError](deinit self, ref[o] on_true: L, var on_false: R) raises _EntryError[X, G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[U, R.Out], R.Error]]] -> Piped[G.Bound[Self.Value, _IfEffect[G, _NativeThunkRef[U, Never, L, False, o], R]]] where G.Element[Self.Value] == Bool and G.Element[U] == G.Element[R.Out] and _ErrorCompatible[_EntryError[X, G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[U, R.Out], R.Error]]], G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[U, R.Out], R.Error]]] and _CarrierCompatible[G, Self.Value] and _CarrierCompatible[G, U] and _CarrierCompatible[G, R.Out]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[G, Self.Value, _NativeThunkRef[U, Never, L, False, o], R, _EntryError[X, G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[U, R.Out], R.Error]]]](self.value^, _NativeThunkRef[U, Never, L, False, o](Pointer(to=on_true)), on_false^))

    def if_effect[U: Movable & Deinitable, o: ImmOrigin, W: Movable & Deinitable, q: ImmOrigin, //, G: Monad, L: _Thunk[U], R: _Thunk[W], X: AnyType = _InferError](deinit self, ref[o] on_true: L, ref[q] on_false: R) raises _EntryError[X, G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[U, W], Never]]] -> Piped[G.Bound[Self.Value, _IfEffect[G, _NativeThunkRef[U, Never, L, False, o], _NativeThunkRef[W, Never, R, False, q]]]] where G.Element[Self.Value] == Bool and G.Element[U] == G.Element[W] and _ErrorCompatible[_EntryError[X, G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[U, W], Never]]], G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[U, W], Never]]] and _CarrierCompatible[G, Self.Value] and _CarrierCompatible[G, U] and _CarrierCompatible[G, W]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[G, Self.Value, _NativeThunkRef[U, Never, L, False, o], _NativeThunkRef[W, Never, R, False, q], _EntryError[X, G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[U, W], Never]]]](self.value^, _NativeThunkRef[U, Never, L, False, o](Pointer(to=on_true)), _NativeThunkRef[W, Never, R, False, q](Pointer(to=on_false))))

    def if_effect[U: Movable & Deinitable, o: ImmOrigin, W: Movable & Deinitable, q: ImmOrigin, //, G: Monad, L: _Thunk[U], D: Movable & Deinitable, R: _RaisingThunk[W, D], X: AnyType = _InferError](deinit self, ref[o] on_true: L, ref[q] on_false: R) raises _EntryError[X, G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[U, W], D]]] -> Piped[G.Bound[Self.Value, _IfEffect[G, _NativeThunkRef[U, Never, L, False, o], _NativeThunkRef[W, D, R, True, q]]]] where G.Element[Self.Value] == Bool and G.Element[U] == G.Element[W] and _ErrorCompatible[_EntryError[X, G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[U, W], D]]], G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[U, W], D]]] and _CarrierCompatible[G, Self.Value] and _CarrierCompatible[G, U] and _CarrierCompatible[G, W]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[G, Self.Value, _NativeThunkRef[U, Never, L, False, o], _NativeThunkRef[W, D, R, True, q], _EntryError[X, G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[U, W], D]]]](self.value^, _NativeThunkRef[U, Never, L, False, o](Pointer(to=on_true)), _NativeThunkRef[W, D, R, True, q](Pointer(to=on_false))))

    def if_effect[U: Movable & Deinitable, o: ImmOrigin, R: ThunkContract & Movable & Deinitable, //, G: Monad, Y: Movable & Deinitable, L: _RaisingThunk[U, Y], X: AnyType = _InferError](deinit self, ref[o] on_true: L, var on_false: R) raises _EntryError[X, G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[U, R.Out], _CommonError[Y, R.Error]]]] -> Piped[G.Bound[Self.Value, _IfEffect[G, _NativeThunkRef[U, Y, L, True, o], R]]] where G.Element[Self.Value] == Bool and G.Element[U] == G.Element[R.Out] and _ErrorCompatible[_EntryError[X, G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[U, R.Out], _CommonError[Y, R.Error]]]], G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[U, R.Out], _CommonError[Y, R.Error]]]] and _CarrierCompatible[G, Self.Value] and _CarrierCompatible[G, U] and _CarrierCompatible[G, R.Out]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[G, Self.Value, _NativeThunkRef[U, Y, L, True, o], R, _EntryError[X, G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[U, R.Out], _CommonError[Y, R.Error]]]]](self.value^, _NativeThunkRef[U, Y, L, True, o](Pointer(to=on_true)), on_false^))

    def if_effect[U: Movable & Deinitable, o: ImmOrigin, W: Movable & Deinitable, q: ImmOrigin, //, G: Monad, Y: Movable & Deinitable, L: _RaisingThunk[U, Y], R: _Thunk[W], X: AnyType = _InferError](deinit self, ref[o] on_true: L, ref[q] on_false: R) raises _EntryError[X, G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[U, W], Y]]] -> Piped[G.Bound[Self.Value, _IfEffect[G, _NativeThunkRef[U, Y, L, True, o], _NativeThunkRef[W, Never, R, False, q]]]] where G.Element[Self.Value] == Bool and G.Element[U] == G.Element[W] and _ErrorCompatible[_EntryError[X, G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[U, W], Y]]], G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[U, W], Y]]] and _CarrierCompatible[G, Self.Value] and _CarrierCompatible[G, U] and _CarrierCompatible[G, W]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[G, Self.Value, _NativeThunkRef[U, Y, L, True, o], _NativeThunkRef[W, Never, R, False, q], _EntryError[X, G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[U, W], Y]]]](self.value^, _NativeThunkRef[U, Y, L, True, o](Pointer(to=on_true)), _NativeThunkRef[W, Never, R, False, q](Pointer(to=on_false))))

    def if_effect[U: Movable & Deinitable, o: ImmOrigin, W: Movable & Deinitable, q: ImmOrigin, //, G: Monad, Y: Movable & Deinitable, L: _RaisingThunk[U, Y], D: Movable & Deinitable, R: _RaisingThunk[W, D], X: AnyType = _InferError](deinit self, ref[o] on_true: L, ref[q] on_false: R) raises _EntryError[X, G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[U, W], _CommonError[Y, D]]]] -> Piped[G.Bound[Self.Value, _IfEffect[G, _NativeThunkRef[U, Y, L, True, o], _NativeThunkRef[W, D, R, True, q]]]] where G.Element[Self.Value] == Bool and G.Element[U] == G.Element[W] and _ErrorCompatible[_EntryError[X, G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[U, W], _CommonError[Y, D]]]], G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[U, W], _CommonError[Y, D]]]] and _CarrierCompatible[G, Self.Value] and _CarrierCompatible[G, U] and _CarrierCompatible[G, W]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[G, Self.Value, _NativeThunkRef[U, Y, L, True, o], _NativeThunkRef[W, D, R, True, q], _EntryError[X, G.BindError[Self.Value, _ErrorProbe[Bool, G._Joined[U, W], _CommonError[Y, D]]]]](self.value^, _NativeThunkRef[U, Y, L, True, o](Pointer(to=on_true)), _NativeThunkRef[W, D, R, True, q](Pointer(to=on_false))))

    def if_effect[L: ThunkContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable, //, X: AnyType = _InferError](deinit self, var on_true: L, var on_false: R) raises _EntryError[X, IfContract[ListFamily, List[Bool], L, R].Error] -> Piped[IfContract[ListFamily, List[Bool], L, R].Out] where Self.Value == List[Bool] and IfContract[ListFamily, List[Bool], L, R].ShapeCompatible and _ErrorCompatible[_EntryError[X, IfContract[ListFamily, List[Bool], L, R].Error], IfContract[ListFamily, List[Bool], L, R].Error]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence.

        Parameters:
            L: The true-branch factory, retaining its native error and receiver mode.
            R: The false-branch factory, retaining its native error and receiver mode.
            X: The exact construction error for generic forwarding; checked without converting errors.

        Args:
            on_true: The branch factory, consumed; invoked only for its selected Bool outcome.
            on_false: The branch factory, consumed; invoked only for its selected Bool outcome.

        Returns:
            The selected branch effect; absence or failure in the condition skips both factories.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_if_effect[ListFamily, List[Bool], L, R, _EntryError[X, IfContract[ListFamily, List[Bool], L, R].Error]](rebind_var[List[Bool]](self.value^), on_true^, on_false^))

    def if_effect[L: ThunkContract & Movable & Deinitable, W: Movable & Deinitable, q: ImmOrigin, //, R: _Thunk[W], X: AnyType = _InferError](deinit self, var on_true: L, ref[q] on_false: R) raises _EntryError[X, ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[L.Out, W], L.Error]]] -> Piped[ListFamily.Bound[List[Bool], _IfEffect[ListFamily, L, _NativeThunkRef[W, Never, R, False, q]]]] where Self.Value == List[Bool] and ListFamily.Element[L.Out] == ListFamily.Element[W] and _ErrorCompatible[_EntryError[X, ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[L.Out, W], L.Error]]], ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[L.Out, W], L.Error]]] and _CarrierCompatible[ListFamily, List[Bool]] and _CarrierCompatible[ListFamily, L.Out] and _CarrierCompatible[ListFamily, W]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[ListFamily, List[Bool], L, _NativeThunkRef[W, Never, R, False, q], _EntryError[X, ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[L.Out, W], L.Error]]]](rebind_var[List[Bool]](self.value^), on_true^, _NativeThunkRef[W, Never, R, False, q](Pointer(to=on_false))))

    def if_effect[L: ThunkContract & Movable & Deinitable, W: Movable & Deinitable, q: ImmOrigin, //, D: Movable & Deinitable, R: _RaisingThunk[W, D], X: AnyType = _InferError](deinit self, var on_true: L, ref[q] on_false: R) raises _EntryError[X, ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[L.Out, W], _CommonError[L.Error, D]]]] -> Piped[ListFamily.Bound[List[Bool], _IfEffect[ListFamily, L, _NativeThunkRef[W, D, R, True, q]]]] where Self.Value == List[Bool] and ListFamily.Element[L.Out] == ListFamily.Element[W] and _ErrorCompatible[_EntryError[X, ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[L.Out, W], _CommonError[L.Error, D]]]], ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[L.Out, W], _CommonError[L.Error, D]]]] and _CarrierCompatible[ListFamily, List[Bool]] and _CarrierCompatible[ListFamily, L.Out] and _CarrierCompatible[ListFamily, W]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[ListFamily, List[Bool], L, _NativeThunkRef[W, D, R, True, q], _EntryError[X, ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[L.Out, W], _CommonError[L.Error, D]]]]](rebind_var[List[Bool]](self.value^), on_true^, _NativeThunkRef[W, D, R, True, q](Pointer(to=on_false))))

    def if_effect[U: Movable & Deinitable, o: ImmOrigin, R: ThunkContract & Movable & Deinitable, //, L: _Thunk[U], X: AnyType = _InferError](deinit self, ref[o] on_true: L, var on_false: R) raises _EntryError[X, ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[U, R.Out], R.Error]]] -> Piped[ListFamily.Bound[List[Bool], _IfEffect[ListFamily, _NativeThunkRef[U, Never, L, False, o], R]]] where Self.Value == List[Bool] and ListFamily.Element[U] == ListFamily.Element[R.Out] and _ErrorCompatible[_EntryError[X, ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[U, R.Out], R.Error]]], ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[U, R.Out], R.Error]]] and _CarrierCompatible[ListFamily, List[Bool]] and _CarrierCompatible[ListFamily, U] and _CarrierCompatible[ListFamily, R.Out]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[ListFamily, List[Bool], _NativeThunkRef[U, Never, L, False, o], R, _EntryError[X, ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[U, R.Out], R.Error]]]](rebind_var[List[Bool]](self.value^), _NativeThunkRef[U, Never, L, False, o](Pointer(to=on_true)), on_false^))

    def if_effect[U: Movable & Deinitable, o: ImmOrigin, W: Movable & Deinitable, q: ImmOrigin, //, L: _Thunk[U], R: _Thunk[W], X: AnyType = _InferError](deinit self, ref[o] on_true: L, ref[q] on_false: R) raises _EntryError[X, ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[U, W], Never]]] -> Piped[ListFamily.Bound[List[Bool], _IfEffect[ListFamily, _NativeThunkRef[U, Never, L, False, o], _NativeThunkRef[W, Never, R, False, q]]]] where Self.Value == List[Bool] and ListFamily.Element[U] == ListFamily.Element[W] and _ErrorCompatible[_EntryError[X, ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[U, W], Never]]], ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[U, W], Never]]] and _CarrierCompatible[ListFamily, List[Bool]] and _CarrierCompatible[ListFamily, U] and _CarrierCompatible[ListFamily, W]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[ListFamily, List[Bool], _NativeThunkRef[U, Never, L, False, o], _NativeThunkRef[W, Never, R, False, q], _EntryError[X, ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[U, W], Never]]]](rebind_var[List[Bool]](self.value^), _NativeThunkRef[U, Never, L, False, o](Pointer(to=on_true)), _NativeThunkRef[W, Never, R, False, q](Pointer(to=on_false))))

    def if_effect[U: Movable & Deinitable, o: ImmOrigin, W: Movable & Deinitable, q: ImmOrigin, //, L: _Thunk[U], D: Movable & Deinitable, R: _RaisingThunk[W, D], X: AnyType = _InferError](deinit self, ref[o] on_true: L, ref[q] on_false: R) raises _EntryError[X, ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[U, W], D]]] -> Piped[ListFamily.Bound[List[Bool], _IfEffect[ListFamily, _NativeThunkRef[U, Never, L, False, o], _NativeThunkRef[W, D, R, True, q]]]] where Self.Value == List[Bool] and ListFamily.Element[U] == ListFamily.Element[W] and _ErrorCompatible[_EntryError[X, ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[U, W], D]]], ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[U, W], D]]] and _CarrierCompatible[ListFamily, List[Bool]] and _CarrierCompatible[ListFamily, U] and _CarrierCompatible[ListFamily, W]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[ListFamily, List[Bool], _NativeThunkRef[U, Never, L, False, o], _NativeThunkRef[W, D, R, True, q], _EntryError[X, ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[U, W], D]]]](rebind_var[List[Bool]](self.value^), _NativeThunkRef[U, Never, L, False, o](Pointer(to=on_true)), _NativeThunkRef[W, D, R, True, q](Pointer(to=on_false))))

    def if_effect[U: Movable & Deinitable, o: ImmOrigin, R: ThunkContract & Movable & Deinitable, //, Y: Movable & Deinitable, L: _RaisingThunk[U, Y], X: AnyType = _InferError](deinit self, ref[o] on_true: L, var on_false: R) raises _EntryError[X, ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[U, R.Out], _CommonError[Y, R.Error]]]] -> Piped[ListFamily.Bound[List[Bool], _IfEffect[ListFamily, _NativeThunkRef[U, Y, L, True, o], R]]] where Self.Value == List[Bool] and ListFamily.Element[U] == ListFamily.Element[R.Out] and _ErrorCompatible[_EntryError[X, ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[U, R.Out], _CommonError[Y, R.Error]]]], ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[U, R.Out], _CommonError[Y, R.Error]]]] and _CarrierCompatible[ListFamily, List[Bool]] and _CarrierCompatible[ListFamily, U] and _CarrierCompatible[ListFamily, R.Out]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[ListFamily, List[Bool], _NativeThunkRef[U, Y, L, True, o], R, _EntryError[X, ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[U, R.Out], _CommonError[Y, R.Error]]]]](rebind_var[List[Bool]](self.value^), _NativeThunkRef[U, Y, L, True, o](Pointer(to=on_true)), on_false^))

    def if_effect[U: Movable & Deinitable, o: ImmOrigin, W: Movable & Deinitable, q: ImmOrigin, //, Y: Movable & Deinitable, L: _RaisingThunk[U, Y], R: _Thunk[W], X: AnyType = _InferError](deinit self, ref[o] on_true: L, ref[q] on_false: R) raises _EntryError[X, ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[U, W], Y]]] -> Piped[ListFamily.Bound[List[Bool], _IfEffect[ListFamily, _NativeThunkRef[U, Y, L, True, o], _NativeThunkRef[W, Never, R, False, q]]]] where Self.Value == List[Bool] and ListFamily.Element[U] == ListFamily.Element[W] and _ErrorCompatible[_EntryError[X, ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[U, W], Y]]], ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[U, W], Y]]] and _CarrierCompatible[ListFamily, List[Bool]] and _CarrierCompatible[ListFamily, U] and _CarrierCompatible[ListFamily, W]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[ListFamily, List[Bool], _NativeThunkRef[U, Y, L, True, o], _NativeThunkRef[W, Never, R, False, q], _EntryError[X, ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[U, W], Y]]]](rebind_var[List[Bool]](self.value^), _NativeThunkRef[U, Y, L, True, o](Pointer(to=on_true)), _NativeThunkRef[W, Never, R, False, q](Pointer(to=on_false))))

    def if_effect[U: Movable & Deinitable, o: ImmOrigin, W: Movable & Deinitable, q: ImmOrigin, //, Y: Movable & Deinitable, L: _RaisingThunk[U, Y], D: Movable & Deinitable, R: _RaisingThunk[W, D], X: AnyType = _InferError](deinit self, ref[o] on_true: L, ref[q] on_false: R) raises _EntryError[X, ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[U, W], _CommonError[Y, D]]]] -> Piped[ListFamily.Bound[List[Bool], _IfEffect[ListFamily, _NativeThunkRef[U, Y, L, True, o], _NativeThunkRef[W, D, R, True, q]]]] where Self.Value == List[Bool] and ListFamily.Element[U] == ListFamily.Element[W] and _ErrorCompatible[_EntryError[X, ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[U, W], _CommonError[Y, D]]]], ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[U, W], _CommonError[Y, D]]]] and _CarrierCompatible[ListFamily, List[Bool]] and _CarrierCompatible[ListFamily, U] and _CarrierCompatible[ListFamily, W]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[ListFamily, List[Bool], _NativeThunkRef[U, Y, L, True, o], _NativeThunkRef[W, D, R, True, q], _EntryError[X, ListFamily.BindError[List[Bool], _ErrorProbe[Bool, ListFamily._Joined[U, W], _CommonError[Y, D]]]]](rebind_var[List[Bool]](self.value^), _NativeThunkRef[U, Y, L, True, o](Pointer(to=on_true)), _NativeThunkRef[W, D, R, True, q](Pointer(to=on_false))))

    def if_effect[L: ThunkContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable, //, X: AnyType = _InferError](deinit self, var on_true: L, var on_false: R) raises _EntryError[X, IfContract[OptionalFamily, Optional[Bool], L, R].Error] -> Piped[IfContract[OptionalFamily, Optional[Bool], L, R].Out] where Self.Value == Optional[Bool] and IfContract[OptionalFamily, Optional[Bool], L, R].ShapeCompatible and _ErrorCompatible[_EntryError[X, IfContract[OptionalFamily, Optional[Bool], L, R].Error], IfContract[OptionalFamily, Optional[Bool], L, R].Error]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence.

        Parameters:
            L: The true-branch factory, retaining its native error and receiver mode.
            R: The false-branch factory, retaining its native error and receiver mode.
            X: The exact construction error for generic forwarding; checked without converting errors.

        Args:
            on_true: The branch factory, consumed; invoked only for its selected Bool outcome.
            on_false: The branch factory, consumed; invoked only for its selected Bool outcome.

        Returns:
            The selected branch effect; absence or failure in the condition skips both factories.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_if_effect[OptionalFamily, Optional[Bool], L, R, _EntryError[X, IfContract[OptionalFamily, Optional[Bool], L, R].Error]](rebind_var[Optional[Bool]](self.value^), on_true^, on_false^))

    def if_effect[L: ThunkContract & Movable & Deinitable, W: Movable & Deinitable, q: ImmOrigin, //, R: _Thunk[W], X: AnyType = _InferError](deinit self, var on_true: L, ref[q] on_false: R) raises _EntryError[X, OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[L.Out, W], L.Error]]] -> Piped[OptionalFamily.Bound[Optional[Bool], _IfEffect[OptionalFamily, L, _NativeThunkRef[W, Never, R, False, q]]]] where Self.Value == Optional[Bool] and OptionalFamily.Element[L.Out] == OptionalFamily.Element[W] and _ErrorCompatible[_EntryError[X, OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[L.Out, W], L.Error]]], OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[L.Out, W], L.Error]]] and _CarrierCompatible[OptionalFamily, Optional[Bool]] and _CarrierCompatible[OptionalFamily, L.Out] and _CarrierCompatible[OptionalFamily, W]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[OptionalFamily, Optional[Bool], L, _NativeThunkRef[W, Never, R, False, q], _EntryError[X, OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[L.Out, W], L.Error]]]](rebind_var[Optional[Bool]](self.value^), on_true^, _NativeThunkRef[W, Never, R, False, q](Pointer(to=on_false))))

    def if_effect[L: ThunkContract & Movable & Deinitable, W: Movable & Deinitable, q: ImmOrigin, //, D: Movable & Deinitable, R: _RaisingThunk[W, D], X: AnyType = _InferError](deinit self, var on_true: L, ref[q] on_false: R) raises _EntryError[X, OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[L.Out, W], _CommonError[L.Error, D]]]] -> Piped[OptionalFamily.Bound[Optional[Bool], _IfEffect[OptionalFamily, L, _NativeThunkRef[W, D, R, True, q]]]] where Self.Value == Optional[Bool] and OptionalFamily.Element[L.Out] == OptionalFamily.Element[W] and _ErrorCompatible[_EntryError[X, OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[L.Out, W], _CommonError[L.Error, D]]]], OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[L.Out, W], _CommonError[L.Error, D]]]] and _CarrierCompatible[OptionalFamily, Optional[Bool]] and _CarrierCompatible[OptionalFamily, L.Out] and _CarrierCompatible[OptionalFamily, W]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[OptionalFamily, Optional[Bool], L, _NativeThunkRef[W, D, R, True, q], _EntryError[X, OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[L.Out, W], _CommonError[L.Error, D]]]]](rebind_var[Optional[Bool]](self.value^), on_true^, _NativeThunkRef[W, D, R, True, q](Pointer(to=on_false))))

    def if_effect[U: Movable & Deinitable, o: ImmOrigin, R: ThunkContract & Movable & Deinitable, //, L: _Thunk[U], X: AnyType = _InferError](deinit self, ref[o] on_true: L, var on_false: R) raises _EntryError[X, OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[U, R.Out], R.Error]]] -> Piped[OptionalFamily.Bound[Optional[Bool], _IfEffect[OptionalFamily, _NativeThunkRef[U, Never, L, False, o], R]]] where Self.Value == Optional[Bool] and OptionalFamily.Element[U] == OptionalFamily.Element[R.Out] and _ErrorCompatible[_EntryError[X, OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[U, R.Out], R.Error]]], OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[U, R.Out], R.Error]]] and _CarrierCompatible[OptionalFamily, Optional[Bool]] and _CarrierCompatible[OptionalFamily, U] and _CarrierCompatible[OptionalFamily, R.Out]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[OptionalFamily, Optional[Bool], _NativeThunkRef[U, Never, L, False, o], R, _EntryError[X, OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[U, R.Out], R.Error]]]](rebind_var[Optional[Bool]](self.value^), _NativeThunkRef[U, Never, L, False, o](Pointer(to=on_true)), on_false^))

    def if_effect[U: Movable & Deinitable, o: ImmOrigin, W: Movable & Deinitable, q: ImmOrigin, //, L: _Thunk[U], R: _Thunk[W], X: AnyType = _InferError](deinit self, ref[o] on_true: L, ref[q] on_false: R) raises _EntryError[X, OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[U, W], Never]]] -> Piped[OptionalFamily.Bound[Optional[Bool], _IfEffect[OptionalFamily, _NativeThunkRef[U, Never, L, False, o], _NativeThunkRef[W, Never, R, False, q]]]] where Self.Value == Optional[Bool] and OptionalFamily.Element[U] == OptionalFamily.Element[W] and _ErrorCompatible[_EntryError[X, OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[U, W], Never]]], OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[U, W], Never]]] and _CarrierCompatible[OptionalFamily, Optional[Bool]] and _CarrierCompatible[OptionalFamily, U] and _CarrierCompatible[OptionalFamily, W]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[OptionalFamily, Optional[Bool], _NativeThunkRef[U, Never, L, False, o], _NativeThunkRef[W, Never, R, False, q], _EntryError[X, OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[U, W], Never]]]](rebind_var[Optional[Bool]](self.value^), _NativeThunkRef[U, Never, L, False, o](Pointer(to=on_true)), _NativeThunkRef[W, Never, R, False, q](Pointer(to=on_false))))

    def if_effect[U: Movable & Deinitable, o: ImmOrigin, W: Movable & Deinitable, q: ImmOrigin, //, L: _Thunk[U], D: Movable & Deinitable, R: _RaisingThunk[W, D], X: AnyType = _InferError](deinit self, ref[o] on_true: L, ref[q] on_false: R) raises _EntryError[X, OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[U, W], D]]] -> Piped[OptionalFamily.Bound[Optional[Bool], _IfEffect[OptionalFamily, _NativeThunkRef[U, Never, L, False, o], _NativeThunkRef[W, D, R, True, q]]]] where Self.Value == Optional[Bool] and OptionalFamily.Element[U] == OptionalFamily.Element[W] and _ErrorCompatible[_EntryError[X, OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[U, W], D]]], OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[U, W], D]]] and _CarrierCompatible[OptionalFamily, Optional[Bool]] and _CarrierCompatible[OptionalFamily, U] and _CarrierCompatible[OptionalFamily, W]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[OptionalFamily, Optional[Bool], _NativeThunkRef[U, Never, L, False, o], _NativeThunkRef[W, D, R, True, q], _EntryError[X, OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[U, W], D]]]](rebind_var[Optional[Bool]](self.value^), _NativeThunkRef[U, Never, L, False, o](Pointer(to=on_true)), _NativeThunkRef[W, D, R, True, q](Pointer(to=on_false))))

    def if_effect[U: Movable & Deinitable, o: ImmOrigin, R: ThunkContract & Movable & Deinitable, //, Y: Movable & Deinitable, L: _RaisingThunk[U, Y], X: AnyType = _InferError](deinit self, ref[o] on_true: L, var on_false: R) raises _EntryError[X, OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[U, R.Out], _CommonError[Y, R.Error]]]] -> Piped[OptionalFamily.Bound[Optional[Bool], _IfEffect[OptionalFamily, _NativeThunkRef[U, Y, L, True, o], R]]] where Self.Value == Optional[Bool] and OptionalFamily.Element[U] == OptionalFamily.Element[R.Out] and _ErrorCompatible[_EntryError[X, OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[U, R.Out], _CommonError[Y, R.Error]]]], OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[U, R.Out], _CommonError[Y, R.Error]]]] and _CarrierCompatible[OptionalFamily, Optional[Bool]] and _CarrierCompatible[OptionalFamily, U] and _CarrierCompatible[OptionalFamily, R.Out]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[OptionalFamily, Optional[Bool], _NativeThunkRef[U, Y, L, True, o], R, _EntryError[X, OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[U, R.Out], _CommonError[Y, R.Error]]]]](rebind_var[Optional[Bool]](self.value^), _NativeThunkRef[U, Y, L, True, o](Pointer(to=on_true)), on_false^))

    def if_effect[U: Movable & Deinitable, o: ImmOrigin, W: Movable & Deinitable, q: ImmOrigin, //, Y: Movable & Deinitable, L: _RaisingThunk[U, Y], R: _Thunk[W], X: AnyType = _InferError](deinit self, ref[o] on_true: L, ref[q] on_false: R) raises _EntryError[X, OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[U, W], Y]]] -> Piped[OptionalFamily.Bound[Optional[Bool], _IfEffect[OptionalFamily, _NativeThunkRef[U, Y, L, True, o], _NativeThunkRef[W, Never, R, False, q]]]] where Self.Value == Optional[Bool] and OptionalFamily.Element[U] == OptionalFamily.Element[W] and _ErrorCompatible[_EntryError[X, OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[U, W], Y]]], OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[U, W], Y]]] and _CarrierCompatible[OptionalFamily, Optional[Bool]] and _CarrierCompatible[OptionalFamily, U] and _CarrierCompatible[OptionalFamily, W]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[OptionalFamily, Optional[Bool], _NativeThunkRef[U, Y, L, True, o], _NativeThunkRef[W, Never, R, False, q], _EntryError[X, OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[U, W], Y]]]](rebind_var[Optional[Bool]](self.value^), _NativeThunkRef[U, Y, L, True, o](Pointer(to=on_true)), _NativeThunkRef[W, Never, R, False, q](Pointer(to=on_false))))

    def if_effect[U: Movable & Deinitable, o: ImmOrigin, W: Movable & Deinitable, q: ImmOrigin, //, Y: Movable & Deinitable, L: _RaisingThunk[U, Y], D: Movable & Deinitable, R: _RaisingThunk[W, D], X: AnyType = _InferError](deinit self, ref[o] on_true: L, ref[q] on_false: R) raises _EntryError[X, OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[U, W], _CommonError[Y, D]]]] -> Piped[OptionalFamily.Bound[Optional[Bool], _IfEffect[OptionalFamily, _NativeThunkRef[U, Y, L, True, o], _NativeThunkRef[W, D, R, True, q]]]] where Self.Value == Optional[Bool] and OptionalFamily.Element[U] == OptionalFamily.Element[W] and _ErrorCompatible[_EntryError[X, OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[U, W], _CommonError[Y, D]]]], OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[U, W], _CommonError[Y, D]]]] and _CarrierCompatible[OptionalFamily, Optional[Bool]] and _CarrierCompatible[OptionalFamily, U] and _CarrierCompatible[OptionalFamily, W]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[OptionalFamily, Optional[Bool], _NativeThunkRef[U, Y, L, True, o], _NativeThunkRef[W, D, R, True, q], _EntryError[X, OptionalFamily.BindError[Optional[Bool], _ErrorProbe[Bool, OptionalFamily._Joined[U, W], _CommonError[Y, D]]]]](rebind_var[Optional[Bool]](self.value^), _NativeThunkRef[U, Y, L, True, o](Pointer(to=on_true)), _NativeThunkRef[W, D, R, True, q](Pointer(to=on_false))))

    def if_effect[L: ThunkContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable, Failure: Movable & Deinitable, //, X: AnyType = _InferError](deinit self, var on_true: L, var on_false: R) raises _EntryError[X, IfContract[ResultFamily[Failure], Result[Bool, Failure], L, R].Error] -> Piped[IfContract[ResultFamily[Failure], Result[Bool, Failure], L, R].Out] where Self.Value == Result[Bool, Failure] and IfContract[ResultFamily[Failure], Result[Bool, Failure], L, R].ShapeCompatible and _ErrorCompatible[_EntryError[X, IfContract[ResultFamily[Failure], Result[Bool, Failure], L, R].Error], IfContract[ResultFamily[Failure], Result[Bool, Failure], L, R].Error]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence.

        Parameters:
            L: The true-branch factory, retaining its native error and receiver mode.
            R: The false-branch factory, retaining its native error and receiver mode.
            Failure: The error payload type retained by Result.
            X: The exact construction error for generic forwarding; checked without converting errors.

        Args:
            on_true: The branch factory, consumed; invoked only for its selected Bool outcome.
            on_false: The branch factory, consumed; invoked only for its selected Bool outcome.

        Returns:
            The selected branch effect; absence or failure in the condition skips both factories.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_if_effect[ResultFamily[Failure], Result[Bool, Failure], L, R, _EntryError[X, IfContract[ResultFamily[Failure], Result[Bool, Failure], L, R].Error]](rebind_var[Result[Bool, Failure]](self.value^), on_true^, on_false^))

    def if_effect[L: ThunkContract & Movable & Deinitable, W: Movable & Deinitable, q: ImmOrigin, Failure: Movable & Deinitable, //, R: _Thunk[W], X: AnyType = _InferError](deinit self, var on_true: L, ref[q] on_false: R) raises _EntryError[X, ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[L.Out, W], L.Error]]] -> Piped[ResultFamily[Failure].Bound[Result[Bool, Failure], _IfEffect[ResultFamily[Failure], L, _NativeThunkRef[W, Never, R, False, q]]]] where Self.Value == Result[Bool, Failure] and ResultFamily[Failure].Element[L.Out] == ResultFamily[Failure].Element[W] and _ErrorCompatible[_EntryError[X, ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[L.Out, W], L.Error]]], ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[L.Out, W], L.Error]]] and _CarrierCompatible[ResultFamily[Failure], Result[Bool, Failure]] and _CarrierCompatible[ResultFamily[Failure], L.Out] and _CarrierCompatible[ResultFamily[Failure], W]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[ResultFamily[Failure], Result[Bool, Failure], L, _NativeThunkRef[W, Never, R, False, q], _EntryError[X, ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[L.Out, W], L.Error]]]](rebind_var[Result[Bool, Failure]](self.value^), on_true^, _NativeThunkRef[W, Never, R, False, q](Pointer(to=on_false))))

    def if_effect[L: ThunkContract & Movable & Deinitable, W: Movable & Deinitable, q: ImmOrigin, Failure: Movable & Deinitable, //, D: Movable & Deinitable, R: _RaisingThunk[W, D], X: AnyType = _InferError](deinit self, var on_true: L, ref[q] on_false: R) raises _EntryError[X, ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[L.Out, W], _CommonError[L.Error, D]]]] -> Piped[ResultFamily[Failure].Bound[Result[Bool, Failure], _IfEffect[ResultFamily[Failure], L, _NativeThunkRef[W, D, R, True, q]]]] where Self.Value == Result[Bool, Failure] and ResultFamily[Failure].Element[L.Out] == ResultFamily[Failure].Element[W] and _ErrorCompatible[_EntryError[X, ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[L.Out, W], _CommonError[L.Error, D]]]], ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[L.Out, W], _CommonError[L.Error, D]]]] and _CarrierCompatible[ResultFamily[Failure], Result[Bool, Failure]] and _CarrierCompatible[ResultFamily[Failure], L.Out] and _CarrierCompatible[ResultFamily[Failure], W]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[ResultFamily[Failure], Result[Bool, Failure], L, _NativeThunkRef[W, D, R, True, q], _EntryError[X, ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[L.Out, W], _CommonError[L.Error, D]]]]](rebind_var[Result[Bool, Failure]](self.value^), on_true^, _NativeThunkRef[W, D, R, True, q](Pointer(to=on_false))))

    def if_effect[U: Movable & Deinitable, o: ImmOrigin, R: ThunkContract & Movable & Deinitable, Failure: Movable & Deinitable, //, L: _Thunk[U], X: AnyType = _InferError](deinit self, ref[o] on_true: L, var on_false: R) raises _EntryError[X, ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[U, R.Out], R.Error]]] -> Piped[ResultFamily[Failure].Bound[Result[Bool, Failure], _IfEffect[ResultFamily[Failure], _NativeThunkRef[U, Never, L, False, o], R]]] where Self.Value == Result[Bool, Failure] and ResultFamily[Failure].Element[U] == ResultFamily[Failure].Element[R.Out] and _ErrorCompatible[_EntryError[X, ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[U, R.Out], R.Error]]], ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[U, R.Out], R.Error]]] and _CarrierCompatible[ResultFamily[Failure], Result[Bool, Failure]] and _CarrierCompatible[ResultFamily[Failure], U] and _CarrierCompatible[ResultFamily[Failure], R.Out]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[ResultFamily[Failure], Result[Bool, Failure], _NativeThunkRef[U, Never, L, False, o], R, _EntryError[X, ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[U, R.Out], R.Error]]]](rebind_var[Result[Bool, Failure]](self.value^), _NativeThunkRef[U, Never, L, False, o](Pointer(to=on_true)), on_false^))

    def if_effect[U: Movable & Deinitable, o: ImmOrigin, W: Movable & Deinitable, q: ImmOrigin, Failure: Movable & Deinitable, //, L: _Thunk[U], R: _Thunk[W], X: AnyType = _InferError](deinit self, ref[o] on_true: L, ref[q] on_false: R) raises _EntryError[X, ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[U, W], Never]]] -> Piped[ResultFamily[Failure].Bound[Result[Bool, Failure], _IfEffect[ResultFamily[Failure], _NativeThunkRef[U, Never, L, False, o], _NativeThunkRef[W, Never, R, False, q]]]] where Self.Value == Result[Bool, Failure] and ResultFamily[Failure].Element[U] == ResultFamily[Failure].Element[W] and _ErrorCompatible[_EntryError[X, ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[U, W], Never]]], ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[U, W], Never]]] and _CarrierCompatible[ResultFamily[Failure], Result[Bool, Failure]] and _CarrierCompatible[ResultFamily[Failure], U] and _CarrierCompatible[ResultFamily[Failure], W]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[ResultFamily[Failure], Result[Bool, Failure], _NativeThunkRef[U, Never, L, False, o], _NativeThunkRef[W, Never, R, False, q], _EntryError[X, ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[U, W], Never]]]](rebind_var[Result[Bool, Failure]](self.value^), _NativeThunkRef[U, Never, L, False, o](Pointer(to=on_true)), _NativeThunkRef[W, Never, R, False, q](Pointer(to=on_false))))

    def if_effect[U: Movable & Deinitable, o: ImmOrigin, W: Movable & Deinitable, q: ImmOrigin, Failure: Movable & Deinitable, //, L: _Thunk[U], D: Movable & Deinitable, R: _RaisingThunk[W, D], X: AnyType = _InferError](deinit self, ref[o] on_true: L, ref[q] on_false: R) raises _EntryError[X, ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[U, W], D]]] -> Piped[ResultFamily[Failure].Bound[Result[Bool, Failure], _IfEffect[ResultFamily[Failure], _NativeThunkRef[U, Never, L, False, o], _NativeThunkRef[W, D, R, True, q]]]] where Self.Value == Result[Bool, Failure] and ResultFamily[Failure].Element[U] == ResultFamily[Failure].Element[W] and _ErrorCompatible[_EntryError[X, ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[U, W], D]]], ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[U, W], D]]] and _CarrierCompatible[ResultFamily[Failure], Result[Bool, Failure]] and _CarrierCompatible[ResultFamily[Failure], U] and _CarrierCompatible[ResultFamily[Failure], W]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[ResultFamily[Failure], Result[Bool, Failure], _NativeThunkRef[U, Never, L, False, o], _NativeThunkRef[W, D, R, True, q], _EntryError[X, ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[U, W], D]]]](rebind_var[Result[Bool, Failure]](self.value^), _NativeThunkRef[U, Never, L, False, o](Pointer(to=on_true)), _NativeThunkRef[W, D, R, True, q](Pointer(to=on_false))))

    def if_effect[U: Movable & Deinitable, o: ImmOrigin, R: ThunkContract & Movable & Deinitable, Failure: Movable & Deinitable, //, Y: Movable & Deinitable, L: _RaisingThunk[U, Y], X: AnyType = _InferError](deinit self, ref[o] on_true: L, var on_false: R) raises _EntryError[X, ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[U, R.Out], _CommonError[Y, R.Error]]]] -> Piped[ResultFamily[Failure].Bound[Result[Bool, Failure], _IfEffect[ResultFamily[Failure], _NativeThunkRef[U, Y, L, True, o], R]]] where Self.Value == Result[Bool, Failure] and ResultFamily[Failure].Element[U] == ResultFamily[Failure].Element[R.Out] and _ErrorCompatible[_EntryError[X, ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[U, R.Out], _CommonError[Y, R.Error]]]], ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[U, R.Out], _CommonError[Y, R.Error]]]] and _CarrierCompatible[ResultFamily[Failure], Result[Bool, Failure]] and _CarrierCompatible[ResultFamily[Failure], U] and _CarrierCompatible[ResultFamily[Failure], R.Out]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[ResultFamily[Failure], Result[Bool, Failure], _NativeThunkRef[U, Y, L, True, o], R, _EntryError[X, ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[U, R.Out], _CommonError[Y, R.Error]]]]](rebind_var[Result[Bool, Failure]](self.value^), _NativeThunkRef[U, Y, L, True, o](Pointer(to=on_true)), on_false^))

    def if_effect[U: Movable & Deinitable, o: ImmOrigin, W: Movable & Deinitable, q: ImmOrigin, Failure: Movable & Deinitable, //, Y: Movable & Deinitable, L: _RaisingThunk[U, Y], R: _Thunk[W], X: AnyType = _InferError](deinit self, ref[o] on_true: L, ref[q] on_false: R) raises _EntryError[X, ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[U, W], Y]]] -> Piped[ResultFamily[Failure].Bound[Result[Bool, Failure], _IfEffect[ResultFamily[Failure], _NativeThunkRef[U, Y, L, True, o], _NativeThunkRef[W, Never, R, False, q]]]] where Self.Value == Result[Bool, Failure] and ResultFamily[Failure].Element[U] == ResultFamily[Failure].Element[W] and _ErrorCompatible[_EntryError[X, ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[U, W], Y]]], ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[U, W], Y]]] and _CarrierCompatible[ResultFamily[Failure], Result[Bool, Failure]] and _CarrierCompatible[ResultFamily[Failure], U] and _CarrierCompatible[ResultFamily[Failure], W]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[ResultFamily[Failure], Result[Bool, Failure], _NativeThunkRef[U, Y, L, True, o], _NativeThunkRef[W, Never, R, False, q], _EntryError[X, ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[U, W], Y]]]](rebind_var[Result[Bool, Failure]](self.value^), _NativeThunkRef[U, Y, L, True, o](Pointer(to=on_true)), _NativeThunkRef[W, Never, R, False, q](Pointer(to=on_false))))

    def if_effect[U: Movable & Deinitable, o: ImmOrigin, W: Movable & Deinitable, q: ImmOrigin, Failure: Movable & Deinitable, //, Y: Movable & Deinitable, L: _RaisingThunk[U, Y], D: Movable & Deinitable, R: _RaisingThunk[W, D], X: AnyType = _InferError](deinit self, ref[o] on_true: L, ref[q] on_false: R) raises _EntryError[X, ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[U, W], _CommonError[Y, D]]]] -> Piped[ResultFamily[Failure].Bound[Result[Bool, Failure], _IfEffect[ResultFamily[Failure], _NativeThunkRef[U, Y, L, True, o], _NativeThunkRef[W, D, R, True, q]]]] where Self.Value == Result[Bool, Failure] and ResultFamily[Failure].Element[U] == ResultFamily[Failure].Element[W] and _ErrorCompatible[_EntryError[X, ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[U, W], _CommonError[Y, D]]]], ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[U, W], _CommonError[Y, D]]]] and _CarrierCompatible[ResultFamily[Failure], Result[Bool, Failure]] and _CarrierCompatible[ResultFamily[Failure], U] and _CarrierCompatible[ResultFamily[Failure], W]:
        """Run the factory selected by an effectful Bool, skipping both factories on failure or absence."""
        return Piped(_if_effect[ResultFamily[Failure], Result[Bool, Failure], _NativeThunkRef[U, Y, L, True, o], _NativeThunkRef[W, D, R, True, q], _EntryError[X, ResultFamily[Failure].BindError[Result[Bool, Failure], _ErrorProbe[Bool, ResultFamily[Failure]._Joined[U, W], _CommonError[Y, D]]]]](rebind_var[Result[Bool, Failure]](self.value^), _NativeThunkRef[U, Y, L, True, o](Pointer(to=on_true)), _NativeThunkRef[W, D, R, True, q](Pointer(to=on_false))))
    # --- end effect syntax ---

    # --- container methods (generated) ---
    # Generated by scripts/generate_plain_overloads.py from
    # scripts/generate_pipeline_syntax.py. Edit the templates, not this block.
    # Native receiver signatures recover container parameters at admission.
    # Where clauses preserve origins; nominal checks precede rebinds because
    # Mojo 1.1 does not carry that evidence into bodies. Execution, callback
    # adaptation and construction remain in the algebra operations/families.

    def or_else[F: UnaryContract & Movable & Deinitable, //, I: Applicative](deinit self, var handler: F) raises _ErrorFamily[I].HandleError[Self.Value, F] -> Piped[_ErrorFamily[I].Handled[Self.Value, F]] where conforms_to(I, ApplicativeError) and F.Arg == _ErrorFamily[I].Failure and _ErrorFamily[I]._ErrorCarrier[Self.Value] and _ErrorFamily[I]._ErrorCarrier[F.Out] and I.Element[Self.Value] == I.Element[F.Out]:
        """Recover the selected stored-error layer with a handler effect.

        Success skips the handler. Native raised errors propagate unchanged.
        The family determines timing and branching; repeated error branches
        require a repeatable handler. The selected stored-error type is retained.

        Parameters:
            F: The owned callback, including its exact origins and native errors.
            I: The family selecting the stored-error layer to handle.

        Args:
            handler: Consumes a stored error; native callbacks are borrowed in place.

        Returns:
            A pipeline holding the family's recovered carrier.

        Raises:
            The family's exact construction error; deferred execution errors
            remain in the resulting action's run contract.
        """
        comptime assert _ErrorFamily[I]._Handles[Self.Value, F], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_ErrorFamily[I].HandleError[Self.Value, F], _ErrorFamily[I].HandleError[Self.Value, F]]
        return Piped(_or_else_as[_ErrorFamily[I].HandleError[Self.Value, F], _ErrorFamily[I], Self.Value, F](handler^, self.value^))

    def or_else[A: Movable & Deinitable, o: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, F: _Unary[A, R]](deinit self, ref[o] handler: F) raises _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[A, R, Never]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]]] where conforms_to(I, ApplicativeError) and A == _ErrorFamily[I].Failure and _ErrorFamily[I]._ErrorCarrier[Self.Value] and _ErrorFamily[I]._ErrorCarrier[R] and I.Element[Self.Value] == I.Element[R]:
        """Recover the selected stored-error layer with a handler effect."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[A, R, Never]], _ErrorFamily[I].HandleError[Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]]]
        return Piped(_or_else_as[_ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[A, R, Never]], _ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=handler)), self.value^))

    def or_else[A: Movable & Deinitable, E: Movable & Deinitable, o: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](deinit self, ref[o] handler: F) raises _EntryError[X, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[A, R, E]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _NativeUnaryRef[A, R, E, F, True, o]]] where conforms_to(I, ApplicativeError) and A == _ErrorFamily[I].Failure and (X == _InferError or X == E) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and _ErrorFamily[I]._ErrorCarrier[R] and I.Element[Self.Value] == I.Element[R]:
        """Recover the selected stored-error layer with a handler effect."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _NativeUnaryRef[A, R, E, F, True, o]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[X, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[A, R, E]]], _ErrorFamily[I].HandleError[Self.Value, _NativeUnaryRef[A, R, E, F, True, o]]]
        return Piped(_or_else_as[_EntryError[X, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[A, R, E]]], _ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, E, F, True, o]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=handler)), self.value^))

    def or_else[F: _UnaryViewable, o: ImmOrigin, //, I: Applicative](deinit self, ref[o] handler: F) raises _ErrorFamily[I].HandleError[Self.Value, F._View[o]] -> Piped[_ErrorFamily[I].Handled[Self.Value, F._View[o]]] where conforms_to(I, ApplicativeError) and F._View[o].Arg == _ErrorFamily[I].Failure and _ErrorFamily[I]._ErrorCarrier[Self.Value] and _ErrorFamily[I]._ErrorCarrier[F._View[o].Out] and I.Element[Self.Value] == I.Element[F._View[o].Out]:
        """Recover the selected stored-error layer with a handler effect."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, F._View[o]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_ErrorFamily[I].HandleError[Self.Value, F._View[o]], _ErrorFamily[I].HandleError[Self.Value, F._View[o]]]
        return Piped(_or_else_as[_ErrorFamily[I].HandleError[Self.Value, F._View[o]], _ErrorFamily[I], Self.Value, F._View[o]](handler._unary_view(), self.value^))

    def recover[F: UnaryContract & Movable & Deinitable, //, I: Applicative](deinit self, var handler: F) raises _ErrorFamily[I].HandleError[Self.Value, _Recovered[I, F]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _Recovered[I, F]]] where conforms_to(I, ApplicativeError) and F.Arg == _ErrorFamily[I].Failure and F.Out == I.Element[Self.Value] and _ErrorFamily[I]._ErrorCarrier[Self.Value]:
        """Recover the selected stored-error layer with a replacement success value.

        Success skips the handler. Native raised errors propagate unchanged.
        The family determines timing and branching; repeated error branches
        require a repeatable handler. The selected stored-error type is retained.

        Parameters:
            F: The owned callback, including its exact origins and native errors.
            I: The family selecting the stored-error layer to handle.

        Args:
            handler: Consumes a stored error; native callbacks are borrowed in place.

        Returns:
            A pipeline holding the family's recovered carrier.

        Raises:
            The family's exact construction error; deferred execution errors
            remain in the resulting action's run contract.
        """
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _Recovered[I, F]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_ErrorFamily[I].HandleError[Self.Value, _Recovered[I, F]], _ErrorFamily[I].HandleError[Self.Value, _Recovered[I, F]]]
        return Piped(_or_else_as[_ErrorFamily[I].HandleError[Self.Value, _Recovered[I, F]], _ErrorFamily[I], Self.Value, _Recovered[I, F]](_Recovered[I, F](handler^), self.value^))

    def recover[A: Movable & Deinitable, o: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, F: _Unary[A, R]](deinit self, ref[o] handler: F) raises _ErrorFamily[I].HandleError[Self.Value, _Recovered[I, _ErrorProbe[A, R, Never]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _Recovered[I, _NativeUnaryRef[A, R, Never, F, False, o]]]] where conforms_to(I, ApplicativeError) and A == _ErrorFamily[I].Failure and R == I.Element[Self.Value] and _ErrorFamily[I]._ErrorCarrier[Self.Value]:
        """Recover the selected stored-error layer with a replacement success value."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _Recovered[I, _NativeUnaryRef[A, R, Never, F, False, o]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_ErrorFamily[I].HandleError[Self.Value, _Recovered[I, _ErrorProbe[A, R, Never]]], _ErrorFamily[I].HandleError[Self.Value, _Recovered[I, _NativeUnaryRef[A, R, Never, F, False, o]]]]
        return Piped(_or_else_as[_ErrorFamily[I].HandleError[Self.Value, _Recovered[I, _ErrorProbe[A, R, Never]]], _ErrorFamily[I], Self.Value, _Recovered[I, _NativeUnaryRef[A, R, Never, F, False, o]]](_Recovered[I, _NativeUnaryRef[A, R, Never, F, False, o]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=handler))), self.value^))

    def recover[A: Movable & Deinitable, E: Movable & Deinitable, o: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](deinit self, ref[o] handler: F) raises _EntryError[X, _ErrorFamily[I].HandleError[Self.Value, _Recovered[I, _ErrorProbe[A, R, E]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _Recovered[I, _NativeUnaryRef[A, R, E, F, True, o]]]] where conforms_to(I, ApplicativeError) and A == _ErrorFamily[I].Failure and R == I.Element[Self.Value] and (X == _InferError or X == E) and _ErrorFamily[I]._ErrorCarrier[Self.Value]:
        """Recover the selected stored-error layer with a replacement success value."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _Recovered[I, _NativeUnaryRef[A, R, E, F, True, o]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[X, _ErrorFamily[I].HandleError[Self.Value, _Recovered[I, _ErrorProbe[A, R, E]]]], _ErrorFamily[I].HandleError[Self.Value, _Recovered[I, _NativeUnaryRef[A, R, E, F, True, o]]]]
        return Piped(_or_else_as[_EntryError[X, _ErrorFamily[I].HandleError[Self.Value, _Recovered[I, _ErrorProbe[A, R, E]]]], _ErrorFamily[I], Self.Value, _Recovered[I, _NativeUnaryRef[A, R, E, F, True, o]]](_Recovered[I, _NativeUnaryRef[A, R, E, F, True, o]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=handler))), self.value^))

    def recover[F: _UnaryViewable, o: ImmOrigin, //, I: Applicative](deinit self, ref[o] handler: F) raises _ErrorFamily[I].HandleError[Self.Value, _Recovered[I, F._View[o]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _Recovered[I, F._View[o]]]] where conforms_to(I, ApplicativeError) and F._View[o].Arg == _ErrorFamily[I].Failure and F._View[o].Out == I.Element[Self.Value] and _ErrorFamily[I]._ErrorCarrier[Self.Value]:
        """Recover the selected stored-error layer with a replacement success value."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _Recovered[I, F._View[o]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_ErrorFamily[I].HandleError[Self.Value, _Recovered[I, F._View[o]]], _ErrorFamily[I].HandleError[Self.Value, _Recovered[I, F._View[o]]]]
        return Piped(_or_else_as[_ErrorFamily[I].HandleError[Self.Value, _Recovered[I, F._View[o]]], _ErrorFamily[I], Self.Value, _Recovered[I, F._View[o]]](_Recovered[I, F._View[o]](handler._unary_view()), self.value^))

    def recover_if[C: BorrowCallContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable, //, I: Applicative, Z: AnyType = _InferError](deinit self, var predicate: C, var handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[G.Out]], _CommonError[C.Failure, _CommonError[G.Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _Recovered[I, G]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C.Payload == _ErrorFamily[I].Failure and C.Result == Bool and G.Arg == _ErrorFamily[I].Failure and G.Out == I.Element[Self.Value]:
        """Recover matching stored errors with success values.

        The predicate borrows each selected error. A match transfers it to the
        handler; otherwise the same error is reintroduced with the family's fail.
        Success skips both callbacks. Branching requires repeatable callbacks;
        deferred families retain their timing, ownership and origins.

        Parameters:
            C: The borrowing predicate, including its native error and origins.
            G: The consuming recovery handler, including its native error and origins.
            I: The family selecting the stored-error layer.
            Z: Optional exact native construction error for generic forwarding.

        Args:
            predicate: Returns Bool; native callbacks are borrowed in place.
            handler: Consumes a matching error and returns its replacement value or effect.

        Returns:
            A pipeline holding the family's recovered carrier.

        Raises:
            Exact callback or family errors. Deferred execution errors remain
            in the resulting action's run contract; stored errors are not raised.
        """
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _Recovered[I, G]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[G.Out]], _CommonError[C.Failure, _CommonError[G.Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _Recovered[I, G]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[G.Out]], _CommonError[C.Failure, _CommonError[G.Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _Recovered[I, G]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _Recovered[I, G]](predicate^, _Recovered[I, G](handler^)), self.value^))

    def recover_if[C: BorrowCallContract & Movable & Deinitable, A: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, G: _Unary[A, R], Z: AnyType = _InferError](deinit self, var predicate: C, ref[q] handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[R]], _CommonError[C.Failure, _CommonError[Never, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _Recovered[I, _NativeUnaryRef[A, R, Never, G, False, q]]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C.Payload == _ErrorFamily[I].Failure and C.Result == Bool and A == _ErrorFamily[I].Failure and R == I.Element[Self.Value]:
        """Recover matching stored errors with success values."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _Recovered[I, _NativeUnaryRef[A, R, Never, G, False, q]]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[R]], _CommonError[C.Failure, _CommonError[Never, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _Recovered[I, _NativeUnaryRef[A, R, Never, G, False, q]]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[R]], _CommonError[C.Failure, _CommonError[Never, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _Recovered[I, _NativeUnaryRef[A, R, Never, G, False, q]]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _Recovered[I, _NativeUnaryRef[A, R, Never, G, False, q]]](predicate^, _Recovered[I, _NativeUnaryRef[A, R, Never, G, False, q]](_NativeUnaryRef[A, R, Never, G, False, q](Pointer(to=handler)))), self.value^))

    def recover_if[C: BorrowCallContract & Movable & Deinitable, A: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, E: Movable & Deinitable, G: _RaisingUnary[A, R, E], Z: AnyType = _InferError](deinit self, var predicate: C, ref[q] handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[R]], _CommonError[C.Failure, _CommonError[E, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _Recovered[I, _NativeUnaryRef[A, R, E, G, True, q]]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C.Payload == _ErrorFamily[I].Failure and C.Result == Bool and A == _ErrorFamily[I].Failure and R == I.Element[Self.Value]:
        """Recover matching stored errors with success values."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _Recovered[I, _NativeUnaryRef[A, R, E, G, True, q]]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[R]], _CommonError[C.Failure, _CommonError[E, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _Recovered[I, _NativeUnaryRef[A, R, E, G, True, q]]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[R]], _CommonError[C.Failure, _CommonError[E, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _Recovered[I, _NativeUnaryRef[A, R, E, G, True, q]]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _Recovered[I, _NativeUnaryRef[A, R, E, G, True, q]]](predicate^, _Recovered[I, _NativeUnaryRef[A, R, E, G, True, q]](_NativeUnaryRef[A, R, E, G, True, q](Pointer(to=handler)))), self.value^))

    def recover_if[C: BorrowCallContract & Movable & Deinitable, G: _UnaryViewable, q: ImmOrigin, //, I: Applicative, Z: AnyType = _InferError](deinit self, var predicate: C, ref[q] handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[G._View[q].Out]], _CommonError[C.Failure, _CommonError[G._View[q].Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _Recovered[I, G._View[q]]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C.Payload == _ErrorFamily[I].Failure and C.Result == Bool and G._View[q].Arg == _ErrorFamily[I].Failure and G._View[q].Out == I.Element[Self.Value]:
        """Recover matching stored errors with success values."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _Recovered[I, G._View[q]]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[G._View[q].Out]], _CommonError[C.Failure, _CommonError[G._View[q].Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _Recovered[I, G._View[q]]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[G._View[q].Out]], _CommonError[C.Failure, _CommonError[G._View[q].Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _Recovered[I, G._View[q]]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _Recovered[I, G._View[q]]](predicate^, _Recovered[I, G._View[q]](handler._unary_view())), self.value^))

    def recover_if[P: AnyType, S: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, I: Applicative, C: _Borrowing[P, S], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, var handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[G.Out]], _CommonError[Never, _CommonError[G.Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _Recovered[I, G]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and P == _ErrorFamily[I].Failure and S == Bool and G.Arg == _ErrorFamily[I].Failure and G.Out == I.Element[Self.Value]:
        """Recover matching stored errors with success values."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _Recovered[I, G]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[G.Out]], _CommonError[Never, _CommonError[G.Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _Recovered[I, G]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[G.Out]], _CommonError[Never, _CommonError[G.Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _Recovered[I, G]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _Recovered[I, G]](_NativeBorrowRef[P, S, Never, C, False, o](Pointer(to=predicate)), _Recovered[I, G](handler^)), self.value^))

    def recover_if[P: AnyType, S: Movable & Deinitable, o: ImmOrigin, A: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, C: _Borrowing[P, S], G: _Unary[A, R], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, ref[q] handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[R]], _CommonError[Never, _CommonError[Never, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _Recovered[I, _NativeUnaryRef[A, R, Never, G, False, q]]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and P == _ErrorFamily[I].Failure and S == Bool and A == _ErrorFamily[I].Failure and R == I.Element[Self.Value]:
        """Recover matching stored errors with success values."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _Recovered[I, _NativeUnaryRef[A, R, Never, G, False, q]]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[R]], _CommonError[Never, _CommonError[Never, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _Recovered[I, _NativeUnaryRef[A, R, Never, G, False, q]]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[R]], _CommonError[Never, _CommonError[Never, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _Recovered[I, _NativeUnaryRef[A, R, Never, G, False, q]]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _Recovered[I, _NativeUnaryRef[A, R, Never, G, False, q]]](_NativeBorrowRef[P, S, Never, C, False, o](Pointer(to=predicate)), _Recovered[I, _NativeUnaryRef[A, R, Never, G, False, q]](_NativeUnaryRef[A, R, Never, G, False, q](Pointer(to=handler)))), self.value^))

    def recover_if[P: AnyType, S: Movable & Deinitable, o: ImmOrigin, A: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, C: _Borrowing[P, S], E: Movable & Deinitable, G: _RaisingUnary[A, R, E], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, ref[q] handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[R]], _CommonError[Never, _CommonError[E, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _Recovered[I, _NativeUnaryRef[A, R, E, G, True, q]]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and P == _ErrorFamily[I].Failure and S == Bool and A == _ErrorFamily[I].Failure and R == I.Element[Self.Value]:
        """Recover matching stored errors with success values."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _Recovered[I, _NativeUnaryRef[A, R, E, G, True, q]]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[R]], _CommonError[Never, _CommonError[E, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _Recovered[I, _NativeUnaryRef[A, R, E, G, True, q]]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[R]], _CommonError[Never, _CommonError[E, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _Recovered[I, _NativeUnaryRef[A, R, E, G, True, q]]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _Recovered[I, _NativeUnaryRef[A, R, E, G, True, q]]](_NativeBorrowRef[P, S, Never, C, False, o](Pointer(to=predicate)), _Recovered[I, _NativeUnaryRef[A, R, E, G, True, q]](_NativeUnaryRef[A, R, E, G, True, q](Pointer(to=handler)))), self.value^))

    def recover_if[P: AnyType, S: Movable & Deinitable, o: ImmOrigin, G: _UnaryViewable, q: ImmOrigin, //, I: Applicative, C: _Borrowing[P, S], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, ref[q] handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[G._View[q].Out]], _CommonError[Never, _CommonError[G._View[q].Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _Recovered[I, G._View[q]]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and P == _ErrorFamily[I].Failure and S == Bool and G._View[q].Arg == _ErrorFamily[I].Failure and G._View[q].Out == I.Element[Self.Value]:
        """Recover matching stored errors with success values."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _Recovered[I, G._View[q]]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[G._View[q].Out]], _CommonError[Never, _CommonError[G._View[q].Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _Recovered[I, G._View[q]]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[G._View[q].Out]], _CommonError[Never, _CommonError[G._View[q].Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _Recovered[I, G._View[q]]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _Recovered[I, G._View[q]]](_NativeBorrowRef[P, S, Never, C, False, o](Pointer(to=predicate)), _Recovered[I, G._View[q]](handler._unary_view())), self.value^))

    def recover_if[P: AnyType, S: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, I: Applicative, X: Movable & Deinitable, C: _RaisingBorrowing[P, S, X], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, var handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[G.Out]], _CommonError[X, _CommonError[G.Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _Recovered[I, G]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and P == _ErrorFamily[I].Failure and S == Bool and G.Arg == _ErrorFamily[I].Failure and G.Out == I.Element[Self.Value]:
        """Recover matching stored errors with success values."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _Recovered[I, G]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[G.Out]], _CommonError[X, _CommonError[G.Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _Recovered[I, G]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[G.Out]], _CommonError[X, _CommonError[G.Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _Recovered[I, G]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _Recovered[I, G]](_NativeBorrowRef[P, S, X, C, True, o](Pointer(to=predicate)), _Recovered[I, G](handler^)), self.value^))

    def recover_if[P: AnyType, S: Movable & Deinitable, o: ImmOrigin, A: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, X: Movable & Deinitable, C: _RaisingBorrowing[P, S, X], G: _Unary[A, R], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, ref[q] handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[R]], _CommonError[X, _CommonError[Never, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _Recovered[I, _NativeUnaryRef[A, R, Never, G, False, q]]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and P == _ErrorFamily[I].Failure and S == Bool and A == _ErrorFamily[I].Failure and R == I.Element[Self.Value]:
        """Recover matching stored errors with success values."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _Recovered[I, _NativeUnaryRef[A, R, Never, G, False, q]]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[R]], _CommonError[X, _CommonError[Never, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _Recovered[I, _NativeUnaryRef[A, R, Never, G, False, q]]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[R]], _CommonError[X, _CommonError[Never, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _Recovered[I, _NativeUnaryRef[A, R, Never, G, False, q]]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _Recovered[I, _NativeUnaryRef[A, R, Never, G, False, q]]](_NativeBorrowRef[P, S, X, C, True, o](Pointer(to=predicate)), _Recovered[I, _NativeUnaryRef[A, R, Never, G, False, q]](_NativeUnaryRef[A, R, Never, G, False, q](Pointer(to=handler)))), self.value^))

    def recover_if[P: AnyType, S: Movable & Deinitable, o: ImmOrigin, A: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, X: Movable & Deinitable, C: _RaisingBorrowing[P, S, X], E: Movable & Deinitable, G: _RaisingUnary[A, R, E], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, ref[q] handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[R]], _CommonError[X, _CommonError[E, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _Recovered[I, _NativeUnaryRef[A, R, E, G, True, q]]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and P == _ErrorFamily[I].Failure and S == Bool and A == _ErrorFamily[I].Failure and R == I.Element[Self.Value]:
        """Recover matching stored errors with success values."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _Recovered[I, _NativeUnaryRef[A, R, E, G, True, q]]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[R]], _CommonError[X, _CommonError[E, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _Recovered[I, _NativeUnaryRef[A, R, E, G, True, q]]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[R]], _CommonError[X, _CommonError[E, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _Recovered[I, _NativeUnaryRef[A, R, E, G, True, q]]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _Recovered[I, _NativeUnaryRef[A, R, E, G, True, q]]](_NativeBorrowRef[P, S, X, C, True, o](Pointer(to=predicate)), _Recovered[I, _NativeUnaryRef[A, R, E, G, True, q]](_NativeUnaryRef[A, R, E, G, True, q](Pointer(to=handler)))), self.value^))

    def recover_if[P: AnyType, S: Movable & Deinitable, o: ImmOrigin, G: _UnaryViewable, q: ImmOrigin, //, I: Applicative, X: Movable & Deinitable, C: _RaisingBorrowing[P, S, X], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, ref[q] handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[G._View[q].Out]], _CommonError[X, _CommonError[G._View[q].Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _Recovered[I, G._View[q]]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and P == _ErrorFamily[I].Failure and S == Bool and G._View[q].Arg == _ErrorFamily[I].Failure and G._View[q].Out == I.Element[Self.Value]:
        """Recover matching stored errors with success values."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _Recovered[I, G._View[q]]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[G._View[q].Out]], _CommonError[X, _CommonError[G._View[q].Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _Recovered[I, G._View[q]]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[G._View[q].Out]], _CommonError[X, _CommonError[G._View[q].Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _Recovered[I, G._View[q]]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _Recovered[I, G._View[q]]](_NativeBorrowRef[P, S, X, C, True, o](Pointer(to=predicate)), _Recovered[I, G._View[q]](handler._unary_view())), self.value^))

    def recover_if[C: _BorrowViewable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, I: Applicative, Z: AnyType = _InferError](deinit self, ref[o] predicate: C, var handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[G.Out]], _CommonError[C._BorrowView[o].Failure, _CommonError[G.Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _Recovered[I, G]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C._BorrowView[o].Payload == _ErrorFamily[I].Failure and C._BorrowView[o].Result == Bool and G.Arg == _ErrorFamily[I].Failure and G.Out == I.Element[Self.Value]:
        """Recover matching stored errors with success values."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _Recovered[I, G]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[G.Out]], _CommonError[C._BorrowView[o].Failure, _CommonError[G.Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _Recovered[I, G]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[G.Out]], _CommonError[C._BorrowView[o].Failure, _CommonError[G.Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _Recovered[I, G]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _Recovered[I, G]](predicate._borrow_view(), _Recovered[I, G](handler^)), self.value^))

    def recover_if[C: _BorrowViewable, o: ImmOrigin, A: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, G: _Unary[A, R], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, ref[q] handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[R]], _CommonError[C._BorrowView[o].Failure, _CommonError[Never, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _Recovered[I, _NativeUnaryRef[A, R, Never, G, False, q]]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C._BorrowView[o].Payload == _ErrorFamily[I].Failure and C._BorrowView[o].Result == Bool and A == _ErrorFamily[I].Failure and R == I.Element[Self.Value]:
        """Recover matching stored errors with success values."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _Recovered[I, _NativeUnaryRef[A, R, Never, G, False, q]]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[R]], _CommonError[C._BorrowView[o].Failure, _CommonError[Never, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _Recovered[I, _NativeUnaryRef[A, R, Never, G, False, q]]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[R]], _CommonError[C._BorrowView[o].Failure, _CommonError[Never, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _Recovered[I, _NativeUnaryRef[A, R, Never, G, False, q]]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _Recovered[I, _NativeUnaryRef[A, R, Never, G, False, q]]](predicate._borrow_view(), _Recovered[I, _NativeUnaryRef[A, R, Never, G, False, q]](_NativeUnaryRef[A, R, Never, G, False, q](Pointer(to=handler)))), self.value^))

    def recover_if[C: _BorrowViewable, o: ImmOrigin, A: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, E: Movable & Deinitable, G: _RaisingUnary[A, R, E], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, ref[q] handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[R]], _CommonError[C._BorrowView[o].Failure, _CommonError[E, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _Recovered[I, _NativeUnaryRef[A, R, E, G, True, q]]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C._BorrowView[o].Payload == _ErrorFamily[I].Failure and C._BorrowView[o].Result == Bool and A == _ErrorFamily[I].Failure and R == I.Element[Self.Value]:
        """Recover matching stored errors with success values."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _Recovered[I, _NativeUnaryRef[A, R, E, G, True, q]]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[R]], _CommonError[C._BorrowView[o].Failure, _CommonError[E, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _Recovered[I, _NativeUnaryRef[A, R, E, G, True, q]]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[R]], _CommonError[C._BorrowView[o].Failure, _CommonError[E, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _Recovered[I, _NativeUnaryRef[A, R, E, G, True, q]]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _Recovered[I, _NativeUnaryRef[A, R, E, G, True, q]]](predicate._borrow_view(), _Recovered[I, _NativeUnaryRef[A, R, E, G, True, q]](_NativeUnaryRef[A, R, E, G, True, q](Pointer(to=handler)))), self.value^))

    def recover_if[C: _BorrowViewable, o: ImmOrigin, G: _UnaryViewable, q: ImmOrigin, //, I: Applicative, Z: AnyType = _InferError](deinit self, ref[o] predicate: C, ref[q] handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[G._View[q].Out]], _CommonError[C._BorrowView[o].Failure, _CommonError[G._View[q].Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _Recovered[I, G._View[q]]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C._BorrowView[o].Payload == _ErrorFamily[I].Failure and C._BorrowView[o].Result == Bool and G._View[q].Arg == _ErrorFamily[I].Failure and G._View[q].Out == I.Element[Self.Value]:
        """Recover matching stored errors with success values."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _Recovered[I, G._View[q]]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[G._View[q].Out]], _CommonError[C._BorrowView[o].Failure, _CommonError[G._View[q].Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _Recovered[I, G._View[q]]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], I.Pure[G._View[q].Out]], _CommonError[C._BorrowView[o].Failure, _CommonError[G._View[q].Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _Recovered[I, G._View[q]]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _Recovered[I, G._View[q]]](predicate._borrow_view(), _Recovered[I, G._View[q]](handler._unary_view())), self.value^))

    def or_else_if[C: BorrowCallContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable, //, I: Applicative, Z: AnyType = _InferError](deinit self, var predicate: C, var handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], G.Out], _CommonError[C.Failure, _CommonError[G.Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, G]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C.Payload == _ErrorFamily[I].Failure and C.Result == Bool and G.Arg == _ErrorFamily[I].Failure and _ErrorFamily[I]._ErrorCarrier[G.Out] and I.Element[G.Out] == I.Element[Self.Value]:
        """Recover matching stored errors with handler effects.

        The predicate borrows each selected error. A match transfers it to the
        handler; otherwise the same error is reintroduced with the family's fail.
        Success skips both callbacks. Branching requires repeatable callbacks;
        deferred families retain their timing, ownership and origins.

        Parameters:
            C: The borrowing predicate, including its native error and origins.
            G: The consuming recovery handler, including its native error and origins.
            I: The family selecting the stored-error layer.
            Z: Optional exact native construction error for generic forwarding.

        Args:
            predicate: Returns Bool; native callbacks are borrowed in place.
            handler: Consumes a matching error and returns its replacement value or effect.

        Returns:
            A pipeline holding the family's recovered carrier.

        Raises:
            Exact callback or family errors. Deferred execution errors remain
            in the resulting action's run contract; stored errors are not raised.
        """
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, G]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], G.Out], _CommonError[C.Failure, _CommonError[G.Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, G]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], G.Out], _CommonError[C.Failure, _CommonError[G.Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, G]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, G](predicate^, handler^), self.value^))

    def or_else_if[C: BorrowCallContract & Movable & Deinitable, A: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, G: _Unary[A, R], Z: AnyType = _InferError](deinit self, var predicate: C, ref[q] handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], R], _CommonError[C.Failure, _CommonError[Never, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _NativeUnaryRef[A, R, Never, G, False, q]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C.Payload == _ErrorFamily[I].Failure and C.Result == Bool and A == _ErrorFamily[I].Failure and _ErrorFamily[I]._ErrorCarrier[R] and I.Element[R] == I.Element[Self.Value]:
        """Recover matching stored errors with handler effects."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _NativeUnaryRef[A, R, Never, G, False, q]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], R], _CommonError[C.Failure, _CommonError[Never, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _NativeUnaryRef[A, R, Never, G, False, q]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], R], _CommonError[C.Failure, _CommonError[Never, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _NativeUnaryRef[A, R, Never, G, False, q]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _NativeUnaryRef[A, R, Never, G, False, q]](predicate^, _NativeUnaryRef[A, R, Never, G, False, q](Pointer(to=handler))), self.value^))

    def or_else_if[C: BorrowCallContract & Movable & Deinitable, A: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, E: Movable & Deinitable, G: _RaisingUnary[A, R, E], Z: AnyType = _InferError](deinit self, var predicate: C, ref[q] handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], R], _CommonError[C.Failure, _CommonError[E, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _NativeUnaryRef[A, R, E, G, True, q]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C.Payload == _ErrorFamily[I].Failure and C.Result == Bool and A == _ErrorFamily[I].Failure and _ErrorFamily[I]._ErrorCarrier[R] and I.Element[R] == I.Element[Self.Value]:
        """Recover matching stored errors with handler effects."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _NativeUnaryRef[A, R, E, G, True, q]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], R], _CommonError[C.Failure, _CommonError[E, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _NativeUnaryRef[A, R, E, G, True, q]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], R], _CommonError[C.Failure, _CommonError[E, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _NativeUnaryRef[A, R, E, G, True, q]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, _NativeUnaryRef[A, R, E, G, True, q]](predicate^, _NativeUnaryRef[A, R, E, G, True, q](Pointer(to=handler))), self.value^))

    def or_else_if[C: BorrowCallContract & Movable & Deinitable, G: _UnaryViewable, q: ImmOrigin, //, I: Applicative, Z: AnyType = _InferError](deinit self, var predicate: C, ref[q] handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], G._View[q].Out], _CommonError[C.Failure, _CommonError[G._View[q].Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, G._View[q]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C.Payload == _ErrorFamily[I].Failure and C.Result == Bool and G._View[q].Arg == _ErrorFamily[I].Failure and _ErrorFamily[I]._ErrorCarrier[G._View[q].Out] and I.Element[G._View[q].Out] == I.Element[Self.Value]:
        """Recover matching stored errors with handler effects."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, G._View[q]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], G._View[q].Out], _CommonError[C.Failure, _CommonError[G._View[q].Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, G._View[q]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], G._View[q].Out], _CommonError[C.Failure, _CommonError[G._View[q].Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, G._View[q]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C, G._View[q]](predicate^, handler._unary_view()), self.value^))

    def or_else_if[P: AnyType, S: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, I: Applicative, C: _Borrowing[P, S], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, var handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], G.Out], _CommonError[Never, _CommonError[G.Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], G]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and P == _ErrorFamily[I].Failure and S == Bool and G.Arg == _ErrorFamily[I].Failure and _ErrorFamily[I]._ErrorCarrier[G.Out] and I.Element[G.Out] == I.Element[Self.Value]:
        """Recover matching stored errors with handler effects."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], G]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], G.Out], _CommonError[Never, _CommonError[G.Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], G]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], G.Out], _CommonError[Never, _CommonError[G.Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], G]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], G](_NativeBorrowRef[P, S, Never, C, False, o](Pointer(to=predicate)), handler^), self.value^))

    def or_else_if[P: AnyType, S: Movable & Deinitable, o: ImmOrigin, A: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, C: _Borrowing[P, S], G: _Unary[A, R], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, ref[q] handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], R], _CommonError[Never, _CommonError[Never, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _NativeUnaryRef[A, R, Never, G, False, q]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and P == _ErrorFamily[I].Failure and S == Bool and A == _ErrorFamily[I].Failure and _ErrorFamily[I]._ErrorCarrier[R] and I.Element[R] == I.Element[Self.Value]:
        """Recover matching stored errors with handler effects."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _NativeUnaryRef[A, R, Never, G, False, q]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], R], _CommonError[Never, _CommonError[Never, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _NativeUnaryRef[A, R, Never, G, False, q]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], R], _CommonError[Never, _CommonError[Never, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _NativeUnaryRef[A, R, Never, G, False, q]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _NativeUnaryRef[A, R, Never, G, False, q]](_NativeBorrowRef[P, S, Never, C, False, o](Pointer(to=predicate)), _NativeUnaryRef[A, R, Never, G, False, q](Pointer(to=handler))), self.value^))

    def or_else_if[P: AnyType, S: Movable & Deinitable, o: ImmOrigin, A: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, C: _Borrowing[P, S], E: Movable & Deinitable, G: _RaisingUnary[A, R, E], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, ref[q] handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], R], _CommonError[Never, _CommonError[E, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _NativeUnaryRef[A, R, E, G, True, q]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and P == _ErrorFamily[I].Failure and S == Bool and A == _ErrorFamily[I].Failure and _ErrorFamily[I]._ErrorCarrier[R] and I.Element[R] == I.Element[Self.Value]:
        """Recover matching stored errors with handler effects."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _NativeUnaryRef[A, R, E, G, True, q]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], R], _CommonError[Never, _CommonError[E, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _NativeUnaryRef[A, R, E, G, True, q]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], R], _CommonError[Never, _CommonError[E, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _NativeUnaryRef[A, R, E, G, True, q]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], _NativeUnaryRef[A, R, E, G, True, q]](_NativeBorrowRef[P, S, Never, C, False, o](Pointer(to=predicate)), _NativeUnaryRef[A, R, E, G, True, q](Pointer(to=handler))), self.value^))

    def or_else_if[P: AnyType, S: Movable & Deinitable, o: ImmOrigin, G: _UnaryViewable, q: ImmOrigin, //, I: Applicative, C: _Borrowing[P, S], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, ref[q] handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], G._View[q].Out], _CommonError[Never, _CommonError[G._View[q].Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], G._View[q]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and P == _ErrorFamily[I].Failure and S == Bool and G._View[q].Arg == _ErrorFamily[I].Failure and _ErrorFamily[I]._ErrorCarrier[G._View[q].Out] and I.Element[G._View[q].Out] == I.Element[Self.Value]:
        """Recover matching stored errors with handler effects."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], G._View[q]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], G._View[q].Out], _CommonError[Never, _CommonError[G._View[q].Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], G._View[q]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], G._View[q].Out], _CommonError[Never, _CommonError[G._View[q].Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], G._View[q]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, Never, C, False, o], G._View[q]](_NativeBorrowRef[P, S, Never, C, False, o](Pointer(to=predicate)), handler._unary_view()), self.value^))

    def or_else_if[P: AnyType, S: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, I: Applicative, X: Movable & Deinitable, C: _RaisingBorrowing[P, S, X], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, var handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], G.Out], _CommonError[X, _CommonError[G.Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], G]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and P == _ErrorFamily[I].Failure and S == Bool and G.Arg == _ErrorFamily[I].Failure and _ErrorFamily[I]._ErrorCarrier[G.Out] and I.Element[G.Out] == I.Element[Self.Value]:
        """Recover matching stored errors with handler effects."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], G]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], G.Out], _CommonError[X, _CommonError[G.Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], G]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], G.Out], _CommonError[X, _CommonError[G.Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], G]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], G](_NativeBorrowRef[P, S, X, C, True, o](Pointer(to=predicate)), handler^), self.value^))

    def or_else_if[P: AnyType, S: Movable & Deinitable, o: ImmOrigin, A: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, X: Movable & Deinitable, C: _RaisingBorrowing[P, S, X], G: _Unary[A, R], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, ref[q] handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], R], _CommonError[X, _CommonError[Never, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _NativeUnaryRef[A, R, Never, G, False, q]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and P == _ErrorFamily[I].Failure and S == Bool and A == _ErrorFamily[I].Failure and _ErrorFamily[I]._ErrorCarrier[R] and I.Element[R] == I.Element[Self.Value]:
        """Recover matching stored errors with handler effects."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _NativeUnaryRef[A, R, Never, G, False, q]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], R], _CommonError[X, _CommonError[Never, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _NativeUnaryRef[A, R, Never, G, False, q]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], R], _CommonError[X, _CommonError[Never, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _NativeUnaryRef[A, R, Never, G, False, q]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _NativeUnaryRef[A, R, Never, G, False, q]](_NativeBorrowRef[P, S, X, C, True, o](Pointer(to=predicate)), _NativeUnaryRef[A, R, Never, G, False, q](Pointer(to=handler))), self.value^))

    def or_else_if[P: AnyType, S: Movable & Deinitable, o: ImmOrigin, A: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, X: Movable & Deinitable, C: _RaisingBorrowing[P, S, X], E: Movable & Deinitable, G: _RaisingUnary[A, R, E], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, ref[q] handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], R], _CommonError[X, _CommonError[E, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _NativeUnaryRef[A, R, E, G, True, q]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and P == _ErrorFamily[I].Failure and S == Bool and A == _ErrorFamily[I].Failure and _ErrorFamily[I]._ErrorCarrier[R] and I.Element[R] == I.Element[Self.Value]:
        """Recover matching stored errors with handler effects."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _NativeUnaryRef[A, R, E, G, True, q]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], R], _CommonError[X, _CommonError[E, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _NativeUnaryRef[A, R, E, G, True, q]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], R], _CommonError[X, _CommonError[E, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _NativeUnaryRef[A, R, E, G, True, q]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], _NativeUnaryRef[A, R, E, G, True, q]](_NativeBorrowRef[P, S, X, C, True, o](Pointer(to=predicate)), _NativeUnaryRef[A, R, E, G, True, q](Pointer(to=handler))), self.value^))

    def or_else_if[P: AnyType, S: Movable & Deinitable, o: ImmOrigin, G: _UnaryViewable, q: ImmOrigin, //, I: Applicative, X: Movable & Deinitable, C: _RaisingBorrowing[P, S, X], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, ref[q] handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], G._View[q].Out], _CommonError[X, _CommonError[G._View[q].Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], G._View[q]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and P == _ErrorFamily[I].Failure and S == Bool and G._View[q].Arg == _ErrorFamily[I].Failure and _ErrorFamily[I]._ErrorCarrier[G._View[q].Out] and I.Element[G._View[q].Out] == I.Element[Self.Value]:
        """Recover matching stored errors with handler effects."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], G._View[q]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], G._View[q].Out], _CommonError[X, _CommonError[G._View[q].Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], G._View[q]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], G._View[q].Out], _CommonError[X, _CommonError[G._View[q].Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], G._View[q]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, S, X, C, True, o], G._View[q]](_NativeBorrowRef[P, S, X, C, True, o](Pointer(to=predicate)), handler._unary_view()), self.value^))

    def or_else_if[C: _BorrowViewable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, I: Applicative, Z: AnyType = _InferError](deinit self, ref[o] predicate: C, var handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], G.Out], _CommonError[C._BorrowView[o].Failure, _CommonError[G.Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], G]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C._BorrowView[o].Payload == _ErrorFamily[I].Failure and C._BorrowView[o].Result == Bool and G.Arg == _ErrorFamily[I].Failure and _ErrorFamily[I]._ErrorCarrier[G.Out] and I.Element[G.Out] == I.Element[Self.Value]:
        """Recover matching stored errors with handler effects."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], G]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], G.Out], _CommonError[C._BorrowView[o].Failure, _CommonError[G.Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], G]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], G.Out], _CommonError[C._BorrowView[o].Failure, _CommonError[G.Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], G]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], G](predicate._borrow_view(), handler^), self.value^))

    def or_else_if[C: _BorrowViewable, o: ImmOrigin, A: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, G: _Unary[A, R], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, ref[q] handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], R], _CommonError[C._BorrowView[o].Failure, _CommonError[Never, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _NativeUnaryRef[A, R, Never, G, False, q]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C._BorrowView[o].Payload == _ErrorFamily[I].Failure and C._BorrowView[o].Result == Bool and A == _ErrorFamily[I].Failure and _ErrorFamily[I]._ErrorCarrier[R] and I.Element[R] == I.Element[Self.Value]:
        """Recover matching stored errors with handler effects."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _NativeUnaryRef[A, R, Never, G, False, q]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], R], _CommonError[C._BorrowView[o].Failure, _CommonError[Never, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _NativeUnaryRef[A, R, Never, G, False, q]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], R], _CommonError[C._BorrowView[o].Failure, _CommonError[Never, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _NativeUnaryRef[A, R, Never, G, False, q]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _NativeUnaryRef[A, R, Never, G, False, q]](predicate._borrow_view(), _NativeUnaryRef[A, R, Never, G, False, q](Pointer(to=handler))), self.value^))

    def or_else_if[C: _BorrowViewable, o: ImmOrigin, A: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, E: Movable & Deinitable, G: _RaisingUnary[A, R, E], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, ref[q] handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], R], _CommonError[C._BorrowView[o].Failure, _CommonError[E, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _NativeUnaryRef[A, R, E, G, True, q]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C._BorrowView[o].Payload == _ErrorFamily[I].Failure and C._BorrowView[o].Result == Bool and A == _ErrorFamily[I].Failure and _ErrorFamily[I]._ErrorCarrier[R] and I.Element[R] == I.Element[Self.Value]:
        """Recover matching stored errors with handler effects."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _NativeUnaryRef[A, R, E, G, True, q]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], R], _CommonError[C._BorrowView[o].Failure, _CommonError[E, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _NativeUnaryRef[A, R, E, G, True, q]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], R], _CommonError[C._BorrowView[o].Failure, _CommonError[E, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _NativeUnaryRef[A, R, E, G, True, q]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], _NativeUnaryRef[A, R, E, G, True, q]](predicate._borrow_view(), _NativeUnaryRef[A, R, E, G, True, q](Pointer(to=handler))), self.value^))

    def or_else_if[C: _BorrowViewable, o: ImmOrigin, G: _UnaryViewable, q: ImmOrigin, //, I: Applicative, Z: AnyType = _InferError](deinit self, ref[o] predicate: C, ref[q] handler: G) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], G._View[q].Out], _CommonError[C._BorrowView[o].Failure, _CommonError[G._View[q].Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], G._View[q]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C._BorrowView[o].Payload == _ErrorFamily[I].Failure and C._BorrowView[o].Result == Bool and G._View[q].Arg == _ErrorFamily[I].Failure and _ErrorFamily[I]._ErrorCarrier[G._View[q].Out] and I.Element[G._View[q].Out] == I.Element[Self.Value]:
        """Recover matching stored errors with handler effects."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], G._View[q]]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], G._View[q].Out], _CommonError[C._BorrowView[o].Failure, _CommonError[G._View[q].Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I].HandleError[Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], G._View[q]]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, I._Joined[_ErrorFamily[I].Failed[I.Element[Self.Value]], G._View[q].Out], _CommonError[C._BorrowView[o].Failure, _CommonError[G._View[q].Error, _ErrorFamily[I].FailError[I.Element[Self.Value]]]]]]], _ErrorFamily[I], Self.Value, _ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], G._View[q]]](_ConditionalRecovery[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], G._View[q]](predicate._borrow_view(), handler._unary_view()), self.value^))

    def tap_err[C: BorrowCallContract & Movable & Deinitable, //, I: Applicative, Z: AnyType = _InferError](deinit self, var inspect: C) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], C.Result, C.Failure, False].Out, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], C.Result, C.Failure, False].Error]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], C, False]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C.Payload == _ErrorFamily[I].Failure:
        """Inspect a borrowed selected error and retain the failure.

        Success skips the observer. Native callbacks are borrowed until execution;
        owned library callbacks move into the computation. Branching requires a
        repeatable observer. Native raised errors propagate with their exact types.
        The observer's result is discarded, including a returned stored failure.
        The original error is reintroduced with the family's fail constructor.

        Parameters:
            C: The borrowing observer, including its exact errors and origins.
            I: The family selecting the stored-error layer.
            Z: Optional exact construction error for generic forwarding.

        Args:
            inspect: Borrows the stored error; called only on that error layer.

        Returns:
            A pipeline holding the family's observed carrier.

        Raises:
            Exact observer, failure-constructor and family errors. Deferred
            execution errors remain in the resulting action's run contract.
        """
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], C, False]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], C.Result, C.Failure, False].Out, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], C.Result, C.Failure, False].Error]]], _ErrorFamily[I].HandleError[Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], C, False]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], C.Result, C.Failure, False].Out, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], C.Result, C.Failure, False].Error]]], _ErrorFamily[I], Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], C, False]](_ObserveError[_ErrorFamily[I], I.Element[Self.Value], C, False](inspect^), self.value^))

    def tap_err[P: AnyType, o: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, C: _Borrowing[P, R], Z: AnyType = _InferError](deinit self, ref[o] inspect: C) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], R, Never, False].Out, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], R, Never, False].Error]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], False]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and P == _ErrorFamily[I].Failure:
        """Inspect a borrowed selected error and retain the failure."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], False]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], R, Never, False].Out, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], R, Never, False].Error]]], _ErrorFamily[I].HandleError[Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], False]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], R, Never, False].Out, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], R, Never, False].Error]]], _ErrorFamily[I], Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], False]](_ObserveError[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], False](_NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=inspect))), self.value^))

    def tap_err[P: AnyType, o: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X], Z: AnyType = _InferError](deinit self, ref[o] inspect: C) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], R, X, False].Out, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], R, X, False].Error]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], False]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and P == _ErrorFamily[I].Failure:
        """Inspect a borrowed selected error and retain the failure."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], False]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], R, X, False].Out, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], R, X, False].Error]]], _ErrorFamily[I].HandleError[Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], False]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], R, X, False].Out, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], R, X, False].Error]]], _ErrorFamily[I], Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], False]](_ObserveError[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], False](_NativeBorrowRef[P, R, X, C, True, o](Pointer(to=inspect))), self.value^))

    def tap_err[C: _BorrowViewable, o: ImmOrigin, //, I: Applicative, Z: AnyType = _InferError](deinit self, ref[o] inspect: C) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o].Result, C._BorrowView[o].Failure, False].Out, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o].Result, C._BorrowView[o].Failure, False].Error]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], False]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C._BorrowView[o].Payload == _ErrorFamily[I].Failure:
        """Inspect a borrowed selected error and retain the failure."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], False]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o].Result, C._BorrowView[o].Failure, False].Out, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o].Result, C._BorrowView[o].Failure, False].Error]]], _ErrorFamily[I].HandleError[Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], False]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o].Result, C._BorrowView[o].Failure, False].Out, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o].Result, C._BorrowView[o].Failure, False].Error]]], _ErrorFamily[I], Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], False]](_ObserveError[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], False](inspect._borrow_view()), self.value^))

    def flat_tap_err[C: BorrowCallContract & Movable & Deinitable, //, I: Applicative, Z: AnyType = _InferError](deinit self, var inspect: C) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], C.Result, C.Failure, True].Out, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], C.Result, C.Failure, True].Error]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], C, True]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C.Payload == _ErrorFamily[I].Failure and _ErrorFamily[I]._ErrorCarrier[C.Result]:
        """Sequence a borrowed error observer using the selected family's combination policy.

        Success skips the observer. Native callbacks are borrowed until execution;
        owned library callbacks move into the computation. Branching requires a
        repeatable observer. Native raised errors propagate with their exact types.
        Observer successes restore the original error. Observer failures follow
        combination: Result keeps the observer error, Validation accumulates it
        before the original. Empty effects remain empty. The family determines
        timing and copies needed for branching; payloads are discarded first.

        Parameters:
            C: The borrowing observer, including its exact errors and origins.
            I: The family selecting the stored-error layer.
            Z: Optional exact construction error for generic forwarding.

        Args:
            inspect: Borrows the stored error; called only on that error layer.

        Returns:
            A pipeline holding the family's observed carrier.

        Raises:
            Exact observer, failure-constructor and family errors. Deferred
            execution errors remain in the resulting action's run contract.
        """
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], C, True]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], C.Result, C.Failure, True].Out, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], C.Result, C.Failure, True].Error]]], _ErrorFamily[I].HandleError[Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], C, True]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], C.Result, C.Failure, True].Out, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], C.Result, C.Failure, True].Error]]], _ErrorFamily[I], Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], C, True]](_ObserveError[_ErrorFamily[I], I.Element[Self.Value], C, True](inspect^), self.value^))

    def flat_tap_err[P: AnyType, o: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, C: _Borrowing[P, R], Z: AnyType = _InferError](deinit self, ref[o] inspect: C) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], R, Never, True].Out, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], R, Never, True].Error]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], True]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and P == _ErrorFamily[I].Failure and _ErrorFamily[I]._ErrorCarrier[R]:
        """Sequence a borrowed error observer using the selected family's combination policy."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], True]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], R, Never, True].Out, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], R, Never, True].Error]]], _ErrorFamily[I].HandleError[Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], True]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], R, Never, True].Out, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], R, Never, True].Error]]], _ErrorFamily[I], Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], True]](_ObserveError[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], True](_NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=inspect))), self.value^))

    def flat_tap_err[P: AnyType, o: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X], Z: AnyType = _InferError](deinit self, ref[o] inspect: C) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], R, X, True].Out, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], R, X, True].Error]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], True]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and P == _ErrorFamily[I].Failure and _ErrorFamily[I]._ErrorCarrier[R]:
        """Sequence a borrowed error observer using the selected family's combination policy."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], True]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], R, X, True].Out, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], R, X, True].Error]]], _ErrorFamily[I].HandleError[Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], True]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], R, X, True].Out, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], R, X, True].Error]]], _ErrorFamily[I], Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], True]](_ObserveError[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], True](_NativeBorrowRef[P, R, X, C, True, o](Pointer(to=inspect))), self.value^))

    def flat_tap_err[C: _BorrowViewable, o: ImmOrigin, //, I: Applicative, Z: AnyType = _InferError](deinit self, ref[o] inspect: C) raises _EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o].Result, C._BorrowView[o].Failure, True].Out, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o].Result, C._BorrowView[o].Failure, True].Error]]] -> Piped[_ErrorFamily[I].Handled[Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], True]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C._BorrowView[o].Payload == _ErrorFamily[I].Failure and _ErrorFamily[I]._ErrorCarrier[C._BorrowView[o].Result]:
        """Sequence a borrowed error observer using the selected family's combination policy."""
        comptime assert _ErrorFamily[I]._Handles[Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], True]], _CALLBACK_ADMISSION
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o].Result, C._BorrowView[o].Failure, True].Out, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o].Result, C._BorrowView[o].Failure, True].Error]]], _ErrorFamily[I].HandleError[Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], True]]]
        return Piped(_or_else_as[_EntryError[Z, _ErrorFamily[I].HandleError[Self.Value, _ErrorProbe[_ErrorFamily[I].Failure, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o].Result, C._BorrowView[o].Failure, True].Out, _ErrorObservation[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o].Result, C._BorrowView[o].Failure, True].Error]]], _ErrorFamily[I], Self.Value, _ObserveError[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], True]](_ObserveError[_ErrorFamily[I], I.Element[Self.Value], C._BorrowView[o], True](inspect._borrow_view()), self.value^))

    def ensure[C: BorrowCallContract & Movable & Deinitable, G: BorrowCallContract & Movable & Deinitable, //, I: Applicative, Z: AnyType = _InferError](deinit self, var predicate: C, var make_error: G) raises _EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], C, G]]] -> Piped[_ErrorMonad[I].Bound[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], C, G]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and conforms_to(I, Monad) and C.Payload == I.Element[Self.Value] and C.Result == Bool and G.Payload == I.Element[Self.Value] and G.Result == _ErrorFamily[I].Failure and (C.Failure == Never or G.Failure == Never or C.Failure == G.Failure):
        """Keep accepted successes; construct a stored failure for rejected values.

        Existing failures skip both callbacks. Predicate and error factory borrow
        the success; the factory runs only on rejection. Branching requires
        repeatable callbacks. Native callbacks remain borrowed until execution;
        library callbacks move into the computation. Stored error types stay fixed.

        Parameters:
            C: The borrowing Bool predicate.
            G: The borrowing stored-error factory.
            I: A Monad with ApplicativeError.
            Z: Optional exact native construction error for generic forwarding.

        Args:
            predicate: Tests each success without consuming it.
            make_error: Borrows a rejected success and returns the selected error type.

        Returns:
            A pipeline holding accepted successes or stored failures.

        Raises:
            Exact callback and family errors; deferred run errors stay deferred.
        """
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], C, G]]], _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], C, G]]]
        return Piped(_flat_map_as[_EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], C, G]]], _ErrorMonad[I]](_Ensure[_ErrorFamily[I], I.Element[Self.Value], C, G](predicate^, make_error^), self.value^))

    def ensure[C: BorrowCallContract & Movable & Deinitable, Q: AnyType, q: ImmOrigin, //, I: Applicative, S: Movable & Deinitable, G: _Borrowing[Q, S], Z: AnyType = _InferError](deinit self, var predicate: C, ref[q] make_error: G) raises _EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], C, _NativeBorrowRef[Q, S, Never, G, False, q]]]] -> Piped[_ErrorMonad[I].Bound[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], C, _NativeBorrowRef[Q, S, Never, G, False, q]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and conforms_to(I, Monad) and C.Payload == I.Element[Self.Value] and C.Result == Bool and Q == I.Element[Self.Value] and S == _ErrorFamily[I].Failure and (C.Failure == Never or Never == Never or C.Failure == Never):
        """Keep accepted successes; construct a stored failure for rejected values."""
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], C, _NativeBorrowRef[Q, S, Never, G, False, q]]]], _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], C, _NativeBorrowRef[Q, S, Never, G, False, q]]]]
        return Piped(_flat_map_as[_EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], C, _NativeBorrowRef[Q, S, Never, G, False, q]]]], _ErrorMonad[I]](_Ensure[_ErrorFamily[I], I.Element[Self.Value], C, _NativeBorrowRef[Q, S, Never, G, False, q]](predicate^, _NativeBorrowRef[Q, S, Never, G, False, q](Pointer(to=make_error))), self.value^))

    def ensure[C: BorrowCallContract & Movable & Deinitable, Q: AnyType, q: ImmOrigin, //, I: Applicative, S: Movable & Deinitable, Y: Movable & Deinitable, G: _RaisingBorrowing[Q, S, Y], Z: AnyType = _InferError](deinit self, var predicate: C, ref[q] make_error: G) raises _EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], C, _NativeBorrowRef[Q, S, Y, G, True, q]]]] -> Piped[_ErrorMonad[I].Bound[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], C, _NativeBorrowRef[Q, S, Y, G, True, q]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and conforms_to(I, Monad) and C.Payload == I.Element[Self.Value] and C.Result == Bool and Q == I.Element[Self.Value] and S == _ErrorFamily[I].Failure and (C.Failure == Never or Y == Never or C.Failure == Y):
        """Keep accepted successes; construct a stored failure for rejected values."""
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], C, _NativeBorrowRef[Q, S, Y, G, True, q]]]], _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], C, _NativeBorrowRef[Q, S, Y, G, True, q]]]]
        return Piped(_flat_map_as[_EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], C, _NativeBorrowRef[Q, S, Y, G, True, q]]]], _ErrorMonad[I]](_Ensure[_ErrorFamily[I], I.Element[Self.Value], C, _NativeBorrowRef[Q, S, Y, G, True, q]](predicate^, _NativeBorrowRef[Q, S, Y, G, True, q](Pointer(to=make_error))), self.value^))

    def ensure[P: AnyType, o: ImmOrigin, G: BorrowCallContract & Movable & Deinitable, //, I: Applicative, R: Movable & Deinitable, C: _Borrowing[P, R], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, var make_error: G) raises _EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], G]]] -> Piped[_ErrorMonad[I].Bound[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], G]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and conforms_to(I, Monad) and P == I.Element[Self.Value] and R == Bool and G.Payload == I.Element[Self.Value] and G.Result == _ErrorFamily[I].Failure and (Never == Never or G.Failure == Never or Never == G.Failure):
        """Keep accepted successes; construct a stored failure for rejected values."""
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], G]]], _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], G]]]
        return Piped(_flat_map_as[_EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], G]]], _ErrorMonad[I]](_Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], G](_NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=predicate)), make_error^), self.value^))

    def ensure[P: AnyType, o: ImmOrigin, Q: AnyType, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, S: Movable & Deinitable, C: _Borrowing[P, R], G: _Borrowing[Q, S], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, ref[q] make_error: G) raises _EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], _NativeBorrowRef[Q, S, Never, G, False, q]]]] -> Piped[_ErrorMonad[I].Bound[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], _NativeBorrowRef[Q, S, Never, G, False, q]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and conforms_to(I, Monad) and P == I.Element[Self.Value] and R == Bool and Q == I.Element[Self.Value] and S == _ErrorFamily[I].Failure and (Never == Never or Never == Never or Never == Never):
        """Keep accepted successes; construct a stored failure for rejected values."""
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], _NativeBorrowRef[Q, S, Never, G, False, q]]]], _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], _NativeBorrowRef[Q, S, Never, G, False, q]]]]
        return Piped(_flat_map_as[_EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], _NativeBorrowRef[Q, S, Never, G, False, q]]]], _ErrorMonad[I]](_Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], _NativeBorrowRef[Q, S, Never, G, False, q]](_NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=predicate)), _NativeBorrowRef[Q, S, Never, G, False, q](Pointer(to=make_error))), self.value^))

    def ensure[P: AnyType, o: ImmOrigin, Q: AnyType, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, S: Movable & Deinitable, C: _Borrowing[P, R], Y: Movable & Deinitable, G: _RaisingBorrowing[Q, S, Y], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, ref[q] make_error: G) raises _EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], _NativeBorrowRef[Q, S, Y, G, True, q]]]] -> Piped[_ErrorMonad[I].Bound[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], _NativeBorrowRef[Q, S, Y, G, True, q]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and conforms_to(I, Monad) and P == I.Element[Self.Value] and R == Bool and Q == I.Element[Self.Value] and S == _ErrorFamily[I].Failure and (Never == Never or Y == Never or Never == Y):
        """Keep accepted successes; construct a stored failure for rejected values."""
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], _NativeBorrowRef[Q, S, Y, G, True, q]]]], _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], _NativeBorrowRef[Q, S, Y, G, True, q]]]]
        return Piped(_flat_map_as[_EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], _NativeBorrowRef[Q, S, Y, G, True, q]]]], _ErrorMonad[I]](_Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, Never, C, False, o], _NativeBorrowRef[Q, S, Y, G, True, q]](_NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=predicate)), _NativeBorrowRef[Q, S, Y, G, True, q](Pointer(to=make_error))), self.value^))

    def ensure[P: AnyType, o: ImmOrigin, G: BorrowCallContract & Movable & Deinitable, //, I: Applicative, R: Movable & Deinitable, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, var make_error: G) raises _EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], G]]] -> Piped[_ErrorMonad[I].Bound[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], G]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and conforms_to(I, Monad) and P == I.Element[Self.Value] and R == Bool and G.Payload == I.Element[Self.Value] and G.Result == _ErrorFamily[I].Failure and (X == Never or G.Failure == Never or X == G.Failure):
        """Keep accepted successes; construct a stored failure for rejected values."""
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], G]]], _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], G]]]
        return Piped(_flat_map_as[_EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], G]]], _ErrorMonad[I]](_Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], G](_NativeBorrowRef[P, R, X, C, True, o](Pointer(to=predicate)), make_error^), self.value^))

    def ensure[P: AnyType, o: ImmOrigin, Q: AnyType, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, S: Movable & Deinitable, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X], G: _Borrowing[Q, S], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, ref[q] make_error: G) raises _EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], _NativeBorrowRef[Q, S, Never, G, False, q]]]] -> Piped[_ErrorMonad[I].Bound[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], _NativeBorrowRef[Q, S, Never, G, False, q]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and conforms_to(I, Monad) and P == I.Element[Self.Value] and R == Bool and Q == I.Element[Self.Value] and S == _ErrorFamily[I].Failure and (X == Never or Never == Never or X == Never):
        """Keep accepted successes; construct a stored failure for rejected values."""
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], _NativeBorrowRef[Q, S, Never, G, False, q]]]], _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], _NativeBorrowRef[Q, S, Never, G, False, q]]]]
        return Piped(_flat_map_as[_EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], _NativeBorrowRef[Q, S, Never, G, False, q]]]], _ErrorMonad[I]](_Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], _NativeBorrowRef[Q, S, Never, G, False, q]](_NativeBorrowRef[P, R, X, C, True, o](Pointer(to=predicate)), _NativeBorrowRef[Q, S, Never, G, False, q](Pointer(to=make_error))), self.value^))

    def ensure[P: AnyType, o: ImmOrigin, Q: AnyType, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, S: Movable & Deinitable, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X], Y: Movable & Deinitable, G: _RaisingBorrowing[Q, S, Y], Z: AnyType = _InferError](deinit self, ref[o] predicate: C, ref[q] make_error: G) raises _EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], _NativeBorrowRef[Q, S, Y, G, True, q]]]] -> Piped[_ErrorMonad[I].Bound[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], _NativeBorrowRef[Q, S, Y, G, True, q]]]] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and conforms_to(I, Monad) and P == I.Element[Self.Value] and R == Bool and Q == I.Element[Self.Value] and S == _ErrorFamily[I].Failure and (X == Never or Y == Never or X == Y):
        """Keep accepted successes; construct a stored failure for rejected values."""
        comptime assert _ErrorCompatible[_EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], _NativeBorrowRef[Q, S, Y, G, True, q]]]], _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], _NativeBorrowRef[Q, S, Y, G, True, q]]]]
        return Piped(_flat_map_as[_EntryError[Z, _ErrorMonad[I].BindError[Self.Value, _Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], _NativeBorrowRef[Q, S, Y, G, True, q]]]], _ErrorMonad[I]](_Ensure[_ErrorFamily[I], I.Element[Self.Value], _NativeBorrowRef[P, R, X, C, True, o], _NativeBorrowRef[Q, S, Y, G, True, q]](_NativeBorrowRef[P, R, X, C, True, o](Pointer(to=predicate)), _NativeBorrowRef[Q, S, Y, G, True, q](Pointer(to=make_error))), self.value^))

    def redeem[C: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable, //, I: Applicative, Z: AnyType = _InferError](deinit self, var on_ok: C, var on_err: G) raises _EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, C, G, False].Error] -> Piped[_Redeem[_ErrorFamily[I], Self.Value, C, G, False].Out] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C.Arg == I.Element[Self.Value] and G.Arg == _ErrorFamily[I].Failure and (C.Error == Never or G.Error == Never or C.Error == G.Error) and C.Out == G.Out:
        """Turn the selected success or stored failure into a successful value.

        Exactly one handler consumes each original outcome. A handler failure
        passes onward without invoking the other handler. The selected stored
        error type stays fixed. Native callbacks remain borrowed until execution;
        library callbacks move into the computation. Branching requires repeatable
        handlers. Unselected callbacks are disposed through the existing family.

        Parameters:
            C: The consuming success handler.
            G: The consuming error handler.
            I: The selected error-capable family; redeem_with also requires Monad.
            Z: Optional exact native construction error for generic forwarding.

        Args:
            on_ok: Consumes an original success.
            on_err: Consumes an original stored error.

        Returns:
            A pipeline with the common success type and the original error type.

        Raises:
            Exact callback and family errors; native raises are never recovered.
        """
        comptime assert _ErrorCompatible[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, C, G, False].Error], _Redeem[_ErrorFamily[I], Self.Value, C, G, False].Error]
        var value = self^.get()
        try:
            return Piped(_Redeem[_ErrorFamily[I], Self.Value, C, G, False].apply(value^, on_ok^, on_err^))
        except raised:
            _propagate_error[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, C, G, False].Error]](raised^)

    def redeem[C: UnaryContract & Movable & Deinitable, Q: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, S: Movable & Deinitable, G: _Unary[Q, S], Z: AnyType = _InferError](deinit self, var on_ok: C, ref[q] on_err: G) raises _EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, C, _NativeUnaryRef[Q, S, Never, G, False, q], False].Error] -> Piped[_Redeem[_ErrorFamily[I], Self.Value, C, _NativeUnaryRef[Q, S, Never, G, False, q], False].Out] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C.Arg == I.Element[Self.Value] and Q == _ErrorFamily[I].Failure and (C.Error == Never or Never == Never or C.Error == Never) and C.Out == S:
        """Turn the selected success or stored failure into a successful value."""
        comptime assert _ErrorCompatible[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, C, _NativeUnaryRef[Q, S, Never, G, False, q], False].Error], _Redeem[_ErrorFamily[I], Self.Value, C, _NativeUnaryRef[Q, S, Never, G, False, q], False].Error]
        var value = self^.get()
        try:
            return Piped(_Redeem[_ErrorFamily[I], Self.Value, C, _NativeUnaryRef[Q, S, Never, G, False, q], False].apply(value^, on_ok^, _NativeUnaryRef[Q, S, Never, G, False, q](Pointer(to=on_err))))
        except raised:
            _propagate_error[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, C, _NativeUnaryRef[Q, S, Never, G, False, q], False].Error]](raised^)

    def redeem[C: UnaryContract & Movable & Deinitable, Q: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, S: Movable & Deinitable, Y: Movable & Deinitable, G: _RaisingUnary[Q, S, Y], Z: AnyType = _InferError](deinit self, var on_ok: C, ref[q] on_err: G) raises _EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, C, _NativeUnaryRef[Q, S, Y, G, True, q], False].Error] -> Piped[_Redeem[_ErrorFamily[I], Self.Value, C, _NativeUnaryRef[Q, S, Y, G, True, q], False].Out] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C.Arg == I.Element[Self.Value] and Q == _ErrorFamily[I].Failure and (C.Error == Never or Y == Never or C.Error == Y) and C.Out == S:
        """Turn the selected success or stored failure into a successful value."""
        comptime assert _ErrorCompatible[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, C, _NativeUnaryRef[Q, S, Y, G, True, q], False].Error], _Redeem[_ErrorFamily[I], Self.Value, C, _NativeUnaryRef[Q, S, Y, G, True, q], False].Error]
        var value = self^.get()
        try:
            return Piped(_Redeem[_ErrorFamily[I], Self.Value, C, _NativeUnaryRef[Q, S, Y, G, True, q], False].apply(value^, on_ok^, _NativeUnaryRef[Q, S, Y, G, True, q](Pointer(to=on_err))))
        except raised:
            _propagate_error[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, C, _NativeUnaryRef[Q, S, Y, G, True, q], False].Error]](raised^)

    def redeem[A: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, I: Applicative, R: Movable & Deinitable, C: _Unary[A, R], Z: AnyType = _InferError](deinit self, ref[o] on_ok: C, var on_err: G) raises _EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], G, False].Error] -> Piped[_Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], G, False].Out] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and A == I.Element[Self.Value] and G.Arg == _ErrorFamily[I].Failure and (Never == Never or G.Error == Never or Never == G.Error) and R == G.Out:
        """Turn the selected success or stored failure into a successful value."""
        comptime assert _ErrorCompatible[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], G, False].Error], _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], G, False].Error]
        var value = self^.get()
        try:
            return Piped(_Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], G, False].apply(value^, _NativeUnaryRef[A, R, Never, C, False, o](Pointer(to=on_ok)), on_err^))
        except raised:
            _propagate_error[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], G, False].Error]](raised^)

    def redeem[A: Movable & Deinitable, o: ImmOrigin, Q: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, S: Movable & Deinitable, C: _Unary[A, R], G: _Unary[Q, S], Z: AnyType = _InferError](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises _EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], _NativeUnaryRef[Q, S, Never, G, False, q], False].Error] -> Piped[_Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], _NativeUnaryRef[Q, S, Never, G, False, q], False].Out] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and A == I.Element[Self.Value] and Q == _ErrorFamily[I].Failure and (Never == Never or Never == Never or Never == Never) and R == S:
        """Turn the selected success or stored failure into a successful value."""
        comptime assert _ErrorCompatible[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], _NativeUnaryRef[Q, S, Never, G, False, q], False].Error], _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], _NativeUnaryRef[Q, S, Never, G, False, q], False].Error]
        var value = self^.get()
        try:
            return Piped(_Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], _NativeUnaryRef[Q, S, Never, G, False, q], False].apply(value^, _NativeUnaryRef[A, R, Never, C, False, o](Pointer(to=on_ok)), _NativeUnaryRef[Q, S, Never, G, False, q](Pointer(to=on_err))))
        except raised:
            _propagate_error[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], _NativeUnaryRef[Q, S, Never, G, False, q], False].Error]](raised^)

    def redeem[A: Movable & Deinitable, o: ImmOrigin, Q: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, S: Movable & Deinitable, C: _Unary[A, R], Y: Movable & Deinitable, G: _RaisingUnary[Q, S, Y], Z: AnyType = _InferError](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises _EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], _NativeUnaryRef[Q, S, Y, G, True, q], False].Error] -> Piped[_Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], _NativeUnaryRef[Q, S, Y, G, True, q], False].Out] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and A == I.Element[Self.Value] and Q == _ErrorFamily[I].Failure and (Never == Never or Y == Never or Never == Y) and R == S:
        """Turn the selected success or stored failure into a successful value."""
        comptime assert _ErrorCompatible[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], _NativeUnaryRef[Q, S, Y, G, True, q], False].Error], _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], _NativeUnaryRef[Q, S, Y, G, True, q], False].Error]
        var value = self^.get()
        try:
            return Piped(_Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], _NativeUnaryRef[Q, S, Y, G, True, q], False].apply(value^, _NativeUnaryRef[A, R, Never, C, False, o](Pointer(to=on_ok)), _NativeUnaryRef[Q, S, Y, G, True, q](Pointer(to=on_err))))
        except raised:
            _propagate_error[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], _NativeUnaryRef[Q, S, Y, G, True, q], False].Error]](raised^)

    def redeem[A: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, I: Applicative, R: Movable & Deinitable, X: Movable & Deinitable, C: _RaisingUnary[A, R, X], Z: AnyType = _InferError](deinit self, ref[o] on_ok: C, var on_err: G) raises _EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], G, False].Error] -> Piped[_Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], G, False].Out] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and A == I.Element[Self.Value] and G.Arg == _ErrorFamily[I].Failure and (X == Never or G.Error == Never or X == G.Error) and R == G.Out:
        """Turn the selected success or stored failure into a successful value."""
        comptime assert _ErrorCompatible[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], G, False].Error], _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], G, False].Error]
        var value = self^.get()
        try:
            return Piped(_Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], G, False].apply(value^, _NativeUnaryRef[A, R, X, C, True, o](Pointer(to=on_ok)), on_err^))
        except raised:
            _propagate_error[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], G, False].Error]](raised^)

    def redeem[A: Movable & Deinitable, o: ImmOrigin, Q: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, S: Movable & Deinitable, X: Movable & Deinitable, C: _RaisingUnary[A, R, X], G: _Unary[Q, S], Z: AnyType = _InferError](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises _EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], _NativeUnaryRef[Q, S, Never, G, False, q], False].Error] -> Piped[_Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], _NativeUnaryRef[Q, S, Never, G, False, q], False].Out] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and A == I.Element[Self.Value] and Q == _ErrorFamily[I].Failure and (X == Never or Never == Never or X == Never) and R == S:
        """Turn the selected success or stored failure into a successful value."""
        comptime assert _ErrorCompatible[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], _NativeUnaryRef[Q, S, Never, G, False, q], False].Error], _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], _NativeUnaryRef[Q, S, Never, G, False, q], False].Error]
        var value = self^.get()
        try:
            return Piped(_Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], _NativeUnaryRef[Q, S, Never, G, False, q], False].apply(value^, _NativeUnaryRef[A, R, X, C, True, o](Pointer(to=on_ok)), _NativeUnaryRef[Q, S, Never, G, False, q](Pointer(to=on_err))))
        except raised:
            _propagate_error[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], _NativeUnaryRef[Q, S, Never, G, False, q], False].Error]](raised^)

    def redeem[A: Movable & Deinitable, o: ImmOrigin, Q: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, S: Movable & Deinitable, X: Movable & Deinitable, C: _RaisingUnary[A, R, X], Y: Movable & Deinitable, G: _RaisingUnary[Q, S, Y], Z: AnyType = _InferError](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises _EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], _NativeUnaryRef[Q, S, Y, G, True, q], False].Error] -> Piped[_Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], _NativeUnaryRef[Q, S, Y, G, True, q], False].Out] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and A == I.Element[Self.Value] and Q == _ErrorFamily[I].Failure and (X == Never or Y == Never or X == Y) and R == S:
        """Turn the selected success or stored failure into a successful value."""
        comptime assert _ErrorCompatible[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], _NativeUnaryRef[Q, S, Y, G, True, q], False].Error], _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], _NativeUnaryRef[Q, S, Y, G, True, q], False].Error]
        var value = self^.get()
        try:
            return Piped(_Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], _NativeUnaryRef[Q, S, Y, G, True, q], False].apply(value^, _NativeUnaryRef[A, R, X, C, True, o](Pointer(to=on_ok)), _NativeUnaryRef[Q, S, Y, G, True, q](Pointer(to=on_err))))
        except raised:
            _propagate_error[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], _NativeUnaryRef[Q, S, Y, G, True, q], False].Error]](raised^)

    def redeem_with[C: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable, //, I: Applicative, Z: AnyType = _InferError](deinit self, var on_ok: C, var on_err: G) raises _EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, C, G, True].Error] -> Piped[_Redeem[_ErrorFamily[I], Self.Value, C, G, True].Out] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C.Arg == I.Element[Self.Value] and G.Arg == _ErrorFamily[I].Failure and (C.Error == Never or G.Error == Never or C.Error == G.Error) and conforms_to(I, Monad) and _ErrorFamily[I]._ErrorCarrier[C.Out] and _ErrorFamily[I]._ErrorCarrier[G.Out] and I.Element[C.Out] == I.Element[G.Out]:
        """Continue the original outcome with its selected handler effect.

        Exactly one handler consumes each original outcome. A handler failure
        passes onward without invoking the other handler. The selected stored
        error type stays fixed. Native callbacks remain borrowed until execution;
        library callbacks move into the computation. Branching requires repeatable
        handlers. Unselected callbacks are disposed through the existing family.

        Parameters:
            C: The consuming success handler.
            G: The consuming error handler.
            I: The selected error-capable family; redeem_with also requires Monad.
            Z: Optional exact native construction error for generic forwarding.

        Args:
            on_ok: Consumes an original success.
            on_err: Consumes an original stored error.

        Returns:
            A pipeline with the common success type and the original error type.

        Raises:
            Exact callback and family errors; native raises are never recovered.
        """
        comptime assert _ErrorCompatible[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, C, G, True].Error], _Redeem[_ErrorFamily[I], Self.Value, C, G, True].Error]
        var value = self^.get()
        try:
            return Piped(_Redeem[_ErrorFamily[I], Self.Value, C, G, True].apply(value^, on_ok^, on_err^))
        except raised:
            _propagate_error[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, C, G, True].Error]](raised^)

    def redeem_with[C: UnaryContract & Movable & Deinitable, Q: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, S: Movable & Deinitable, G: _Unary[Q, S], Z: AnyType = _InferError](deinit self, var on_ok: C, ref[q] on_err: G) raises _EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, C, _NativeUnaryRef[Q, S, Never, G, False, q], True].Error] -> Piped[_Redeem[_ErrorFamily[I], Self.Value, C, _NativeUnaryRef[Q, S, Never, G, False, q], True].Out] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C.Arg == I.Element[Self.Value] and Q == _ErrorFamily[I].Failure and (C.Error == Never or Never == Never or C.Error == Never) and conforms_to(I, Monad) and _ErrorFamily[I]._ErrorCarrier[C.Out] and _ErrorFamily[I]._ErrorCarrier[S] and I.Element[C.Out] == I.Element[S]:
        """Continue the original outcome with its selected handler effect."""
        comptime assert _ErrorCompatible[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, C, _NativeUnaryRef[Q, S, Never, G, False, q], True].Error], _Redeem[_ErrorFamily[I], Self.Value, C, _NativeUnaryRef[Q, S, Never, G, False, q], True].Error]
        var value = self^.get()
        try:
            return Piped(_Redeem[_ErrorFamily[I], Self.Value, C, _NativeUnaryRef[Q, S, Never, G, False, q], True].apply(value^, on_ok^, _NativeUnaryRef[Q, S, Never, G, False, q](Pointer(to=on_err))))
        except raised:
            _propagate_error[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, C, _NativeUnaryRef[Q, S, Never, G, False, q], True].Error]](raised^)

    def redeem_with[C: UnaryContract & Movable & Deinitable, Q: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, S: Movable & Deinitable, Y: Movable & Deinitable, G: _RaisingUnary[Q, S, Y], Z: AnyType = _InferError](deinit self, var on_ok: C, ref[q] on_err: G) raises _EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, C, _NativeUnaryRef[Q, S, Y, G, True, q], True].Error] -> Piped[_Redeem[_ErrorFamily[I], Self.Value, C, _NativeUnaryRef[Q, S, Y, G, True, q], True].Out] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and C.Arg == I.Element[Self.Value] and Q == _ErrorFamily[I].Failure and (C.Error == Never or Y == Never or C.Error == Y) and conforms_to(I, Monad) and _ErrorFamily[I]._ErrorCarrier[C.Out] and _ErrorFamily[I]._ErrorCarrier[S] and I.Element[C.Out] == I.Element[S]:
        """Continue the original outcome with its selected handler effect."""
        comptime assert _ErrorCompatible[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, C, _NativeUnaryRef[Q, S, Y, G, True, q], True].Error], _Redeem[_ErrorFamily[I], Self.Value, C, _NativeUnaryRef[Q, S, Y, G, True, q], True].Error]
        var value = self^.get()
        try:
            return Piped(_Redeem[_ErrorFamily[I], Self.Value, C, _NativeUnaryRef[Q, S, Y, G, True, q], True].apply(value^, on_ok^, _NativeUnaryRef[Q, S, Y, G, True, q](Pointer(to=on_err))))
        except raised:
            _propagate_error[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, C, _NativeUnaryRef[Q, S, Y, G, True, q], True].Error]](raised^)

    def redeem_with[A: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, I: Applicative, R: Movable & Deinitable, C: _Unary[A, R], Z: AnyType = _InferError](deinit self, ref[o] on_ok: C, var on_err: G) raises _EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], G, True].Error] -> Piped[_Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], G, True].Out] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and A == I.Element[Self.Value] and G.Arg == _ErrorFamily[I].Failure and (Never == Never or G.Error == Never or Never == G.Error) and conforms_to(I, Monad) and _ErrorFamily[I]._ErrorCarrier[R] and _ErrorFamily[I]._ErrorCarrier[G.Out] and I.Element[R] == I.Element[G.Out]:
        """Continue the original outcome with its selected handler effect."""
        comptime assert _ErrorCompatible[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], G, True].Error], _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], G, True].Error]
        var value = self^.get()
        try:
            return Piped(_Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], G, True].apply(value^, _NativeUnaryRef[A, R, Never, C, False, o](Pointer(to=on_ok)), on_err^))
        except raised:
            _propagate_error[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], G, True].Error]](raised^)

    def redeem_with[A: Movable & Deinitable, o: ImmOrigin, Q: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, S: Movable & Deinitable, C: _Unary[A, R], G: _Unary[Q, S], Z: AnyType = _InferError](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises _EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], _NativeUnaryRef[Q, S, Never, G, False, q], True].Error] -> Piped[_Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], _NativeUnaryRef[Q, S, Never, G, False, q], True].Out] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and A == I.Element[Self.Value] and Q == _ErrorFamily[I].Failure and (Never == Never or Never == Never or Never == Never) and conforms_to(I, Monad) and _ErrorFamily[I]._ErrorCarrier[R] and _ErrorFamily[I]._ErrorCarrier[S] and I.Element[R] == I.Element[S]:
        """Continue the original outcome with its selected handler effect."""
        comptime assert _ErrorCompatible[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], _NativeUnaryRef[Q, S, Never, G, False, q], True].Error], _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], _NativeUnaryRef[Q, S, Never, G, False, q], True].Error]
        var value = self^.get()
        try:
            return Piped(_Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], _NativeUnaryRef[Q, S, Never, G, False, q], True].apply(value^, _NativeUnaryRef[A, R, Never, C, False, o](Pointer(to=on_ok)), _NativeUnaryRef[Q, S, Never, G, False, q](Pointer(to=on_err))))
        except raised:
            _propagate_error[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], _NativeUnaryRef[Q, S, Never, G, False, q], True].Error]](raised^)

    def redeem_with[A: Movable & Deinitable, o: ImmOrigin, Q: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, S: Movable & Deinitable, C: _Unary[A, R], Y: Movable & Deinitable, G: _RaisingUnary[Q, S, Y], Z: AnyType = _InferError](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises _EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], _NativeUnaryRef[Q, S, Y, G, True, q], True].Error] -> Piped[_Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], _NativeUnaryRef[Q, S, Y, G, True, q], True].Out] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and A == I.Element[Self.Value] and Q == _ErrorFamily[I].Failure and (Never == Never or Y == Never or Never == Y) and conforms_to(I, Monad) and _ErrorFamily[I]._ErrorCarrier[R] and _ErrorFamily[I]._ErrorCarrier[S] and I.Element[R] == I.Element[S]:
        """Continue the original outcome with its selected handler effect."""
        comptime assert _ErrorCompatible[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], _NativeUnaryRef[Q, S, Y, G, True, q], True].Error], _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], _NativeUnaryRef[Q, S, Y, G, True, q], True].Error]
        var value = self^.get()
        try:
            return Piped(_Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], _NativeUnaryRef[Q, S, Y, G, True, q], True].apply(value^, _NativeUnaryRef[A, R, Never, C, False, o](Pointer(to=on_ok)), _NativeUnaryRef[Q, S, Y, G, True, q](Pointer(to=on_err))))
        except raised:
            _propagate_error[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, Never, C, False, o], _NativeUnaryRef[Q, S, Y, G, True, q], True].Error]](raised^)

    def redeem_with[A: Movable & Deinitable, o: ImmOrigin, G: UnaryContract & Movable & Deinitable, //, I: Applicative, R: Movable & Deinitable, X: Movable & Deinitable, C: _RaisingUnary[A, R, X], Z: AnyType = _InferError](deinit self, ref[o] on_ok: C, var on_err: G) raises _EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], G, True].Error] -> Piped[_Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], G, True].Out] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and A == I.Element[Self.Value] and G.Arg == _ErrorFamily[I].Failure and (X == Never or G.Error == Never or X == G.Error) and conforms_to(I, Monad) and _ErrorFamily[I]._ErrorCarrier[R] and _ErrorFamily[I]._ErrorCarrier[G.Out] and I.Element[R] == I.Element[G.Out]:
        """Continue the original outcome with its selected handler effect."""
        comptime assert _ErrorCompatible[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], G, True].Error], _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], G, True].Error]
        var value = self^.get()
        try:
            return Piped(_Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], G, True].apply(value^, _NativeUnaryRef[A, R, X, C, True, o](Pointer(to=on_ok)), on_err^))
        except raised:
            _propagate_error[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], G, True].Error]](raised^)

    def redeem_with[A: Movable & Deinitable, o: ImmOrigin, Q: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, S: Movable & Deinitable, X: Movable & Deinitable, C: _RaisingUnary[A, R, X], G: _Unary[Q, S], Z: AnyType = _InferError](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises _EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], _NativeUnaryRef[Q, S, Never, G, False, q], True].Error] -> Piped[_Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], _NativeUnaryRef[Q, S, Never, G, False, q], True].Out] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and A == I.Element[Self.Value] and Q == _ErrorFamily[I].Failure and (X == Never or Never == Never or X == Never) and conforms_to(I, Monad) and _ErrorFamily[I]._ErrorCarrier[R] and _ErrorFamily[I]._ErrorCarrier[S] and I.Element[R] == I.Element[S]:
        """Continue the original outcome with its selected handler effect."""
        comptime assert _ErrorCompatible[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], _NativeUnaryRef[Q, S, Never, G, False, q], True].Error], _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], _NativeUnaryRef[Q, S, Never, G, False, q], True].Error]
        var value = self^.get()
        try:
            return Piped(_Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], _NativeUnaryRef[Q, S, Never, G, False, q], True].apply(value^, _NativeUnaryRef[A, R, X, C, True, o](Pointer(to=on_ok)), _NativeUnaryRef[Q, S, Never, G, False, q](Pointer(to=on_err))))
        except raised:
            _propagate_error[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], _NativeUnaryRef[Q, S, Never, G, False, q], True].Error]](raised^)

    def redeem_with[A: Movable & Deinitable, o: ImmOrigin, Q: Movable & Deinitable, q: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, S: Movable & Deinitable, X: Movable & Deinitable, C: _RaisingUnary[A, R, X], Y: Movable & Deinitable, G: _RaisingUnary[Q, S, Y], Z: AnyType = _InferError](deinit self, ref[o] on_ok: C, ref[q] on_err: G) raises _EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], _NativeUnaryRef[Q, S, Y, G, True, q], True].Error] -> Piped[_Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], _NativeUnaryRef[Q, S, Y, G, True, q], True].Out] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and A == I.Element[Self.Value] and Q == _ErrorFamily[I].Failure and (X == Never or Y == Never or X == Y) and conforms_to(I, Monad) and _ErrorFamily[I]._ErrorCarrier[R] and _ErrorFamily[I]._ErrorCarrier[S] and I.Element[R] == I.Element[S]:
        """Continue the original outcome with its selected handler effect."""
        comptime assert _ErrorCompatible[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], _NativeUnaryRef[Q, S, Y, G, True, q], True].Error], _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], _NativeUnaryRef[Q, S, Y, G, True, q], True].Error]
        var value = self^.get()
        try:
            return Piped(_Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], _NativeUnaryRef[Q, S, Y, G, True, q], True].apply(value^, _NativeUnaryRef[A, R, X, C, True, o](Pointer(to=on_ok)), _NativeUnaryRef[Q, S, Y, G, True, q](Pointer(to=on_err))))
        except raised:
            _propagate_error[_EntryError[Z, _Redeem[_ErrorFamily[I], Self.Value, _NativeUnaryRef[A, R, X, C, True, o], _NativeUnaryRef[Q, S, Y, G, True, q], True].Error]](raised^)

    def attempt_tap[C: BorrowCallContract & Movable & Deinitable, //, I: Applicative, Z: AnyType = _InferError](deinit self, var inspect: C) raises _EntryError[Z, _AttemptTap[_ErrorMonad[I], Self.Value, C].Error] -> Piped[_AttemptTap[_ErrorMonad[I], Self.Value, C].Out] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and conforms_to(I, Monad) and C.Payload == Result[I.Element[Self.Value], _ErrorFamily[I].Failure] and _ErrorFamily[I]._ErrorCarrier[C.Result]:
        """Observe the whole selected Result and restore it after observer success.

        The observer borrows each original Result, on either success or failure,
        and returns an effect in the same family. Observer failures replace the
        original outcome; empty observer effects stay empty. Branching requires
        a repeatable observer and copyable retained outcomes. Single-use paths
        admit move-only values. Native callbacks remain borrowed until execution.

        Parameters:
            C: The borrowing whole-outcome observer.
            I: A Monad with ApplicativeError, selecting the stored-error layer.
            Z: Optional exact native construction error for generic forwarding.

        Args:
            inspect: Borrows Result[success, stored error] and returns its effect.

        Returns:
            A pipeline retaining the outcome per successful observer branch.

        Raises:
            Exact callback and family errors, retaining deferred run boundaries.
        """
        comptime assert _ErrorCompatible[_EntryError[Z, _AttemptTap[_ErrorMonad[I], Self.Value, C].Error], _AttemptTap[_ErrorMonad[I], Self.Value, C].Error]
        var value = self^.get()
        try:
            return Piped(_AttemptTap[_ErrorMonad[I], Self.Value, C].apply(value^, inspect^))
        except raised:
            _propagate_error[_EntryError[Z, _AttemptTap[_ErrorMonad[I], Self.Value, C].Error]](raised^)

    def attempt_tap[P: AnyType, o: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, C: _Borrowing[P, R], Z: AnyType = _InferError](deinit self, ref[o] inspect: C) raises _EntryError[Z, _AttemptTap[_ErrorMonad[I], Self.Value, _NativeBorrowRef[P, R, Never, C, False, o]].Error] -> Piped[_AttemptTap[_ErrorMonad[I], Self.Value, _NativeBorrowRef[P, R, Never, C, False, o]].Out] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and conforms_to(I, Monad) and P == Result[I.Element[Self.Value], _ErrorFamily[I].Failure] and _ErrorFamily[I]._ErrorCarrier[R]:
        """Observe the whole selected Result and restore it after observer success."""
        comptime assert _ErrorCompatible[_EntryError[Z, _AttemptTap[_ErrorMonad[I], Self.Value, _NativeBorrowRef[P, R, Never, C, False, o]].Error], _AttemptTap[_ErrorMonad[I], Self.Value, _NativeBorrowRef[P, R, Never, C, False, o]].Error]
        var value = self^.get()
        try:
            return Piped(_AttemptTap[_ErrorMonad[I], Self.Value, _NativeBorrowRef[P, R, Never, C, False, o]].apply(value^, _NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=inspect))))
        except raised:
            _propagate_error[_EntryError[Z, _AttemptTap[_ErrorMonad[I], Self.Value, _NativeBorrowRef[P, R, Never, C, False, o]].Error]](raised^)

    def attempt_tap[P: AnyType, o: ImmOrigin, //, I: Applicative, R: Movable & Deinitable, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X], Z: AnyType = _InferError](deinit self, ref[o] inspect: C) raises _EntryError[Z, _AttemptTap[_ErrorMonad[I], Self.Value, _NativeBorrowRef[P, R, X, C, True, o]].Error] -> Piped[_AttemptTap[_ErrorMonad[I], Self.Value, _NativeBorrowRef[P, R, X, C, True, o]].Out] where conforms_to(I, ApplicativeError) and _ErrorFamily[I]._ErrorCarrier[Self.Value] and conforms_to(I, Monad) and P == Result[I.Element[Self.Value], _ErrorFamily[I].Failure] and _ErrorFamily[I]._ErrorCarrier[R]:
        """Observe the whole selected Result and restore it after observer success."""
        comptime assert _ErrorCompatible[_EntryError[Z, _AttemptTap[_ErrorMonad[I], Self.Value, _NativeBorrowRef[P, R, X, C, True, o]].Error], _AttemptTap[_ErrorMonad[I], Self.Value, _NativeBorrowRef[P, R, X, C, True, o]].Error]
        var value = self^.get()
        try:
            return Piped(_AttemptTap[_ErrorMonad[I], Self.Value, _NativeBorrowRef[P, R, X, C, True, o]].apply(value^, _NativeBorrowRef[P, R, X, C, True, o](Pointer(to=inspect))))
        except raised:
            _propagate_error[_EntryError[Z, _AttemptTap[_ErrorMonad[I], Self.Value, _NativeBorrowRef[P, R, X, C, True, o]].Error]](raised^)

    def flat_tap[C: BorrowCallContract & Movable & Deinitable, //, I: Monad](deinit self, var function: C) raises I.BindError[Self.Value, _EffectRetain[I.Element[Self.Value], I, C]] -> Piped[I.Bound[Self.Value, _EffectRetain[I.Element[Self.Value], I, C]]] where True and C.Payload == I.Element[Self.Value] and _CarrierCompatible[I, C.Result]:
        """Sequence a borrowing effectful callback and retain each original value.

        Branches follow bind: no output skips the continuation; each produced
        success emits one output. Retained values must be Copyable for branching
        families. Single-use families move them. Native errors keep their types.

        Parameters:
            C: The callback, with its exact receiver and effect type.
            I: The Monad family, including its timing, branching and error semantics.

        Args:
            function: The callback, consumed; repeatable wherever the source can branch.

        Returns:
            A pipeline holding the family result; deferred families retain callbacks until execution.

        Raises:
            The exact callback or family construction error.
        """
        return Piped(_flat_map_as[I.BindError[Self.Value, _EffectRetain[I.Element[Self.Value], I, C]], I, Self.Value, _EffectRetain[I.Element[Self.Value], I, C]](_EffectRetain[I.Element[Self.Value], I, C](function^), self.value^))

    def flat_tap[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, I: Monad, C: _Borrowing[P, R]](deinit self, ref[o] function: C) raises I.BindError[Self.Value, _EffectRetain[I.Element[Self.Value], I, _NativeBorrowRef[P, R, Never, C, False, o]]] -> Piped[I.Bound[Self.Value, _EffectRetain[I.Element[Self.Value], I, _NativeBorrowRef[P, R, Never, C, False, o]]]] where True and P == I.Element[Self.Value] and _CarrierCompatible[I, R]:
        """Sequence a borrowing effectful callback and retain each original value."""
        return Piped(_flat_map_as[I.BindError[Self.Value, _EffectRetain[I.Element[Self.Value], I, _NativeBorrowRef[P, R, Never, C, False, o]]], I, Self.Value, _EffectRetain[I.Element[Self.Value], I, _NativeBorrowRef[P, R, Never, C, False, o]]](_EffectRetain[I.Element[Self.Value], I, _NativeBorrowRef[P, R, Never, C, False, o]](_NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=function))), self.value^))

    def flat_tap[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, I: Monad, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X]](deinit self, ref[o] function: C) raises I.BindError[Self.Value, _EffectRetain[I.Element[Self.Value], I, _NativeBorrowRef[P, R, X, C, True, o]]] -> Piped[I.Bound[Self.Value, _EffectRetain[I.Element[Self.Value], I, _NativeBorrowRef[P, R, X, C, True, o]]]] where True and P == I.Element[Self.Value] and _CarrierCompatible[I, R]:
        """Sequence a borrowing effectful callback and retain each original value."""
        return Piped(_flat_map_as[I.BindError[Self.Value, _EffectRetain[I.Element[Self.Value], I, _NativeBorrowRef[P, R, X, C, True, o]]], I, Self.Value, _EffectRetain[I.Element[Self.Value], I, _NativeBorrowRef[P, R, X, C, True, o]]](_EffectRetain[I.Element[Self.Value], I, _NativeBorrowRef[P, R, X, C, True, o]](_NativeBorrowRef[P, R, X, C, True, o](Pointer(to=function))), self.value^))

    def flat_pair_with[C: BorrowCallContract & Movable & Deinitable, //, I: Monad](deinit self, var function: C) raises I.BindError[Self.Value, _EffectRetain[I.Element[Self.Value], I, C, False, True]] -> Piped[I.Bound[Self.Value, _EffectRetain[I.Element[Self.Value], I, C, False, True]]] where True and C.Payload == I.Element[Self.Value] and _CarrierCompatible[I, C.Result]:
        """Sequence a borrowing effectful projection and pair each success with its original.

        Each successful projection emits (original, projected). Projected values
        are moved; only retained originals need Copyable when effects branch.


        Branches follow bind: no output skips the continuation; each produced
        success emits one output. Retained values must be Copyable for branching
        families. Single-use families move them. Native errors keep their types.

        Parameters:
            C: The callback, with its exact receiver and effect type.
            I: The Monad family, including its timing, branching and error semantics.

        Args:
            function: The callback, consumed; repeatable wherever the source can branch.

        Returns:
            A pipeline holding the family result; deferred families retain callbacks until execution.

        Raises:
            The exact callback or family construction error.
        """
        return Piped(_flat_map_as[I.BindError[Self.Value, _EffectRetain[I.Element[Self.Value], I, C, False, True]], I, Self.Value, _EffectRetain[I.Element[Self.Value], I, C, False, True]](_EffectRetain[I.Element[Self.Value], I, C, False, True](function^), self.value^))

    def flat_pair_with[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, I: Monad, C: _Borrowing[P, R]](deinit self, ref[o] function: C) raises I.BindError[Self.Value, _EffectRetain[I.Element[Self.Value], I, _NativeBorrowRef[P, R, Never, C, False, o], False, True]] -> Piped[I.Bound[Self.Value, _EffectRetain[I.Element[Self.Value], I, _NativeBorrowRef[P, R, Never, C, False, o], False, True]]] where True and P == I.Element[Self.Value] and _CarrierCompatible[I, R]:
        """Sequence a borrowing effectful projection and pair each success with its original."""
        return Piped(_flat_map_as[I.BindError[Self.Value, _EffectRetain[I.Element[Self.Value], I, _NativeBorrowRef[P, R, Never, C, False, o], False, True]], I, Self.Value, _EffectRetain[I.Element[Self.Value], I, _NativeBorrowRef[P, R, Never, C, False, o], False, True]](_EffectRetain[I.Element[Self.Value], I, _NativeBorrowRef[P, R, Never, C, False, o], False, True](_NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=function))), self.value^))

    def flat_pair_with[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, I: Monad, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X]](deinit self, ref[o] function: C) raises I.BindError[Self.Value, _EffectRetain[I.Element[Self.Value], I, _NativeBorrowRef[P, R, X, C, True, o], False, True]] -> Piped[I.Bound[Self.Value, _EffectRetain[I.Element[Self.Value], I, _NativeBorrowRef[P, R, X, C, True, o], False, True]]] where True and P == I.Element[Self.Value] and _CarrierCompatible[I, R]:
        """Sequence a borrowing effectful projection and pair each success with its original."""
        return Piped(_flat_map_as[I.BindError[Self.Value, _EffectRetain[I.Element[Self.Value], I, _NativeBorrowRef[P, R, X, C, True, o], False, True]], I, Self.Value, _EffectRetain[I.Element[Self.Value], I, _NativeBorrowRef[P, R, X, C, True, o], False, True]](_EffectRetain[I.Element[Self.Value], I, _NativeBorrowRef[P, R, X, C, True, o], False, True](_NativeBorrowRef[P, R, X, C, True, o](Pointer(to=function))), self.value^))

    def followed_by[C: ThunkContract & Movable & Deinitable, //, I: Monad](deinit self, var function: C) raises I.BindError[Self.Value, _BorrowedUnary[I.Element[Self.Value], _IgnoreInput[I.Element[Self.Value], C]]] -> Piped[I.Bound[Self.Value, _BorrowedUnary[I.Element[Self.Value], _IgnoreInput[I.Element[Self.Value], C]]]] where True and _CarrierCompatible[I, C.Out]:
        """Sequence a zero-argument factory and keep its produced values.

        Branches follow bind: no output skips the continuation; each produced
        success emits one output. Retained values must be Copyable for branching
        families. Single-use families move them. Native errors keep their types.

        Parameters:
            C: The callback, with its exact receiver and effect type.
            I: The Monad family, including its timing, branching and error semantics.

        Args:
            function: The callback, consumed; repeatable wherever the source can branch.

        Returns:
            A pipeline holding the family result; deferred families retain callbacks until execution.

        Raises:
            The exact callback or family construction error.
        """
        return Piped(_flat_map_as[I.BindError[Self.Value, _BorrowedUnary[I.Element[Self.Value], _IgnoreInput[I.Element[Self.Value], C]]], I, Self.Value, _BorrowedUnary[I.Element[Self.Value], _IgnoreInput[I.Element[Self.Value], C]]](_BorrowedUnary[I.Element[Self.Value], _IgnoreInput[I.Element[Self.Value], C]](_IgnoreInput[I.Element[Self.Value], C](function^)), self.value^))

    def followed_by[R: Movable & Deinitable, o: ImmOrigin, //, I: Monad, C: _Thunk[R]](deinit self, ref[o] function: C) raises I.BindError[Self.Value, _BorrowedUnary[I.Element[Self.Value], _IgnoreInput[I.Element[Self.Value], _NativeThunkRef[R, Never, C, False, o]]]] -> Piped[I.Bound[Self.Value, _BorrowedUnary[I.Element[Self.Value], _IgnoreInput[I.Element[Self.Value], _NativeThunkRef[R, Never, C, False, o]]]]] where True and _CarrierCompatible[I, R]:
        """Sequence a zero-argument factory and keep its produced values."""
        return Piped(_flat_map_as[I.BindError[Self.Value, _BorrowedUnary[I.Element[Self.Value], _IgnoreInput[I.Element[Self.Value], _NativeThunkRef[R, Never, C, False, o]]]], I, Self.Value, _BorrowedUnary[I.Element[Self.Value], _IgnoreInput[I.Element[Self.Value], _NativeThunkRef[R, Never, C, False, o]]]](_BorrowedUnary[I.Element[Self.Value], _IgnoreInput[I.Element[Self.Value], _NativeThunkRef[R, Never, C, False, o]]](_IgnoreInput[I.Element[Self.Value], _NativeThunkRef[R, Never, C, False, o]](_NativeThunkRef[R, Never, C, False, o](Pointer(to=function)))), self.value^))

    def followed_by[R: Movable & Deinitable, o: ImmOrigin, //, I: Monad, X: Movable & Deinitable, C: _RaisingThunk[R, X]](deinit self, ref[o] function: C) raises I.BindError[Self.Value, _BorrowedUnary[I.Element[Self.Value], _IgnoreInput[I.Element[Self.Value], _NativeThunkRef[R, X, C, True, o]]]] -> Piped[I.Bound[Self.Value, _BorrowedUnary[I.Element[Self.Value], _IgnoreInput[I.Element[Self.Value], _NativeThunkRef[R, X, C, True, o]]]]] where True and _CarrierCompatible[I, R]:
        """Sequence a zero-argument factory and keep its produced values."""
        return Piped(_flat_map_as[I.BindError[Self.Value, _BorrowedUnary[I.Element[Self.Value], _IgnoreInput[I.Element[Self.Value], _NativeThunkRef[R, X, C, True, o]]]], I, Self.Value, _BorrowedUnary[I.Element[Self.Value], _IgnoreInput[I.Element[Self.Value], _NativeThunkRef[R, X, C, True, o]]]](_BorrowedUnary[I.Element[Self.Value], _IgnoreInput[I.Element[Self.Value], _NativeThunkRef[R, X, C, True, o]]](_IgnoreInput[I.Element[Self.Value], _NativeThunkRef[R, X, C, True, o]](_NativeThunkRef[R, X, C, True, o](Pointer(to=function)))), self.value^))

    def before[C: ThunkContract & Movable & Deinitable, //, I: Monad](deinit self, var function: C) raises I.BindError[Self.Value, _EffectRetain[I.Element[Self.Value], I, _IgnoreInput[I.Element[Self.Value], C]]] -> Piped[I.Bound[Self.Value, _EffectRetain[I.Element[Self.Value], I, _IgnoreInput[I.Element[Self.Value], C]]]] where True and _CarrierCompatible[I, C.Out]:
        """Sequence a zero-argument factory and retain each original value.

        Branches follow bind: no output skips the continuation; each produced
        success emits one output. Retained values must be Copyable for branching
        families. Single-use families move them. Native errors keep their types.

        Parameters:
            C: The callback, with its exact receiver and effect type.
            I: The Monad family, including its timing, branching and error semantics.

        Args:
            function: The callback, consumed; repeatable wherever the source can branch.

        Returns:
            A pipeline holding the family result; deferred families retain callbacks until execution.

        Raises:
            The exact callback or family construction error.
        """
        return Piped(_flat_map_as[I.BindError[Self.Value, _EffectRetain[I.Element[Self.Value], I, _IgnoreInput[I.Element[Self.Value], C]]], I, Self.Value, _EffectRetain[I.Element[Self.Value], I, _IgnoreInput[I.Element[Self.Value], C]]](_EffectRetain[I.Element[Self.Value], I, _IgnoreInput[I.Element[Self.Value], C]](_IgnoreInput[I.Element[Self.Value], C](function^)), self.value^))

    def before[R: Movable & Deinitable, o: ImmOrigin, //, I: Monad, C: _Thunk[R]](deinit self, ref[o] function: C) raises I.BindError[Self.Value, _EffectRetain[I.Element[Self.Value], I, _IgnoreInput[I.Element[Self.Value], _NativeThunkRef[R, Never, C, False, o]]]] -> Piped[I.Bound[Self.Value, _EffectRetain[I.Element[Self.Value], I, _IgnoreInput[I.Element[Self.Value], _NativeThunkRef[R, Never, C, False, o]]]]] where True and _CarrierCompatible[I, R]:
        """Sequence a zero-argument factory and retain each original value."""
        return Piped(_flat_map_as[I.BindError[Self.Value, _EffectRetain[I.Element[Self.Value], I, _IgnoreInput[I.Element[Self.Value], _NativeThunkRef[R, Never, C, False, o]]]], I, Self.Value, _EffectRetain[I.Element[Self.Value], I, _IgnoreInput[I.Element[Self.Value], _NativeThunkRef[R, Never, C, False, o]]]](_EffectRetain[I.Element[Self.Value], I, _IgnoreInput[I.Element[Self.Value], _NativeThunkRef[R, Never, C, False, o]]](_IgnoreInput[I.Element[Self.Value], _NativeThunkRef[R, Never, C, False, o]](_NativeThunkRef[R, Never, C, False, o](Pointer(to=function)))), self.value^))

    def before[R: Movable & Deinitable, o: ImmOrigin, //, I: Monad, X: Movable & Deinitable, C: _RaisingThunk[R, X]](deinit self, ref[o] function: C) raises I.BindError[Self.Value, _EffectRetain[I.Element[Self.Value], I, _IgnoreInput[I.Element[Self.Value], _NativeThunkRef[R, X, C, True, o]]]] -> Piped[I.Bound[Self.Value, _EffectRetain[I.Element[Self.Value], I, _IgnoreInput[I.Element[Self.Value], _NativeThunkRef[R, X, C, True, o]]]]] where True and _CarrierCompatible[I, R]:
        """Sequence a zero-argument factory and retain each original value."""
        return Piped(_flat_map_as[I.BindError[Self.Value, _EffectRetain[I.Element[Self.Value], I, _IgnoreInput[I.Element[Self.Value], _NativeThunkRef[R, X, C, True, o]]]], I, Self.Value, _EffectRetain[I.Element[Self.Value], I, _IgnoreInput[I.Element[Self.Value], _NativeThunkRef[R, X, C, True, o]]]](_EffectRetain[I.Element[Self.Value], I, _IgnoreInput[I.Element[Self.Value], _NativeThunkRef[R, X, C, True, o]]](_IgnoreInput[I.Element[Self.Value], _NativeThunkRef[R, X, C, True, o]](_NativeThunkRef[R, X, C, True, o](Pointer(to=function)))), self.value^))

    def flat_tap[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, //](deinit self, var function: C) raises C.Failure -> Piped[ListFamily.Bound[List[T], _EffectRetain[T, ListFamily, C]]] where Self.Value == List[T] and C.Payload == T and _CarrierCompatible[ListFamily, C.Result]:
        """Sequence a borrowing effectful callback and retain each original value.

        Branches follow bind: no output skips the continuation; each produced
        success emits one output. Retained values must be Copyable for branching
        families. Single-use families move them. Native errors keep their types.

        Parameters:
            T: The source payload type, including origins.
            C: The callback, with its exact receiver and effect type.

        Args:
            function: The callback, consumed; repeatable wherever the source can branch.

        Returns:
            A pipeline holding the family result; deferred families retain callbacks until execution.

        Raises:
            The exact callback or family construction error.
        """
        comptime assert Self.Value == List[T]
        comptime assert _ErrorCompatible[C.Failure, ListFamily.BindError[List[T], _EffectRetain[T, ListFamily, C]]]
        return Piped(_flat_map_as[C.Failure, ListFamily, List[T], _EffectRetain[T, ListFamily, C]](_EffectRetain[T, ListFamily, C](function^), rebind_var[List[T]](self.value^)))

    def flat_tap[T: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, C: _Borrowing[P, R]](deinit self, ref[o] function: C) raises Never -> Piped[ListFamily.Bound[List[T], _EffectRetain[T, ListFamily, _NativeBorrowRef[P, R, Never, C, False, o]]]] where Self.Value == List[T] and P == T and _CarrierCompatible[ListFamily, R]:
        """Sequence a borrowing effectful callback and retain each original value."""
        comptime assert Self.Value == List[T]
        comptime assert _ErrorCompatible[Never, ListFamily.BindError[List[T], _EffectRetain[T, ListFamily, _NativeBorrowRef[P, R, Never, C, False, o]]]]
        return Piped(_flat_map_as[Never, ListFamily, List[T], _EffectRetain[T, ListFamily, _NativeBorrowRef[P, R, Never, C, False, o]]](_EffectRetain[T, ListFamily, _NativeBorrowRef[P, R, Never, C, False, o]](_NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=function))), rebind_var[List[T]](self.value^)))

    def flat_tap[T: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X]](deinit self, ref[o] function: C) raises X -> Piped[ListFamily.Bound[List[T], _EffectRetain[T, ListFamily, _NativeBorrowRef[P, R, X, C, True, o]]]] where Self.Value == List[T] and P == T and _CarrierCompatible[ListFamily, R]:
        """Sequence a borrowing effectful callback and retain each original value."""
        comptime assert Self.Value == List[T]
        comptime assert _ErrorCompatible[X, ListFamily.BindError[List[T], _EffectRetain[T, ListFamily, _NativeBorrowRef[P, R, X, C, True, o]]]]
        return Piped(_flat_map_as[X, ListFamily, List[T], _EffectRetain[T, ListFamily, _NativeBorrowRef[P, R, X, C, True, o]]](_EffectRetain[T, ListFamily, _NativeBorrowRef[P, R, X, C, True, o]](_NativeBorrowRef[P, R, X, C, True, o](Pointer(to=function))), rebind_var[List[T]](self.value^)))

    def flat_pair_with[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, //](deinit self, var function: C) raises C.Failure -> Piped[ListFamily.Bound[List[T], _EffectRetain[T, ListFamily, C, False, True]]] where Self.Value == List[T] and C.Payload == T and _CarrierCompatible[ListFamily, C.Result]:
        """Sequence a borrowing effectful projection and pair each success with its original.

        Each successful projection emits (original, projected). Projected values
        are moved; only retained originals need Copyable when effects branch.


        Branches follow bind: no output skips the continuation; each produced
        success emits one output. Retained values must be Copyable for branching
        families. Single-use families move them. Native errors keep their types.

        Parameters:
            T: The source payload type, including origins.
            C: The callback, with its exact receiver and effect type.

        Args:
            function: The callback, consumed; repeatable wherever the source can branch.

        Returns:
            A pipeline holding the family result; deferred families retain callbacks until execution.

        Raises:
            The exact callback or family construction error.
        """
        comptime assert Self.Value == List[T]
        comptime assert _ErrorCompatible[C.Failure, ListFamily.BindError[List[T], _EffectRetain[T, ListFamily, C, False, True]]]
        return Piped(_flat_map_as[C.Failure, ListFamily, List[T], _EffectRetain[T, ListFamily, C, False, True]](_EffectRetain[T, ListFamily, C, False, True](function^), rebind_var[List[T]](self.value^)))

    def flat_pair_with[T: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, C: _Borrowing[P, R]](deinit self, ref[o] function: C) raises Never -> Piped[ListFamily.Bound[List[T], _EffectRetain[T, ListFamily, _NativeBorrowRef[P, R, Never, C, False, o], False, True]]] where Self.Value == List[T] and P == T and _CarrierCompatible[ListFamily, R]:
        """Sequence a borrowing effectful projection and pair each success with its original."""
        comptime assert Self.Value == List[T]
        comptime assert _ErrorCompatible[Never, ListFamily.BindError[List[T], _EffectRetain[T, ListFamily, _NativeBorrowRef[P, R, Never, C, False, o], False, True]]]
        return Piped(_flat_map_as[Never, ListFamily, List[T], _EffectRetain[T, ListFamily, _NativeBorrowRef[P, R, Never, C, False, o], False, True]](_EffectRetain[T, ListFamily, _NativeBorrowRef[P, R, Never, C, False, o], False, True](_NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=function))), rebind_var[List[T]](self.value^)))

    def flat_pair_with[T: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X]](deinit self, ref[o] function: C) raises X -> Piped[ListFamily.Bound[List[T], _EffectRetain[T, ListFamily, _NativeBorrowRef[P, R, X, C, True, o], False, True]]] where Self.Value == List[T] and P == T and _CarrierCompatible[ListFamily, R]:
        """Sequence a borrowing effectful projection and pair each success with its original."""
        comptime assert Self.Value == List[T]
        comptime assert _ErrorCompatible[X, ListFamily.BindError[List[T], _EffectRetain[T, ListFamily, _NativeBorrowRef[P, R, X, C, True, o], False, True]]]
        return Piped(_flat_map_as[X, ListFamily, List[T], _EffectRetain[T, ListFamily, _NativeBorrowRef[P, R, X, C, True, o], False, True]](_EffectRetain[T, ListFamily, _NativeBorrowRef[P, R, X, C, True, o], False, True](_NativeBorrowRef[P, R, X, C, True, o](Pointer(to=function))), rebind_var[List[T]](self.value^)))

    def followed_by[T: Movable & Deinitable, C: ThunkContract & Movable & Deinitable, //](deinit self, var function: C) raises C.Error -> Piped[ListFamily.Bound[List[T], _BorrowedUnary[T, _IgnoreInput[T, C]]]] where Self.Value == List[T] and _CarrierCompatible[ListFamily, C.Out]:
        """Sequence a zero-argument factory and keep its produced values.

        Branches follow bind: no output skips the continuation; each produced
        success emits one output. Retained values must be Copyable for branching
        families. Single-use families move them. Native errors keep their types.

        Parameters:
            T: The source payload type, including origins.
            C: The callback, with its exact receiver and effect type.

        Args:
            function: The callback, consumed; repeatable wherever the source can branch.

        Returns:
            A pipeline holding the family result; deferred families retain callbacks until execution.

        Raises:
            The exact callback or family construction error.
        """
        comptime assert Self.Value == List[T]
        comptime assert _ErrorCompatible[C.Error, ListFamily.BindError[List[T], _BorrowedUnary[T, _IgnoreInput[T, C]]]]
        return Piped(_flat_map_as[C.Error, ListFamily, List[T], _BorrowedUnary[T, _IgnoreInput[T, C]]](_BorrowedUnary[T, _IgnoreInput[T, C]](_IgnoreInput[T, C](function^)), rebind_var[List[T]](self.value^)))

    def followed_by[T: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, C: _Thunk[R]](deinit self, ref[o] function: C) raises Never -> Piped[ListFamily.Bound[List[T], _BorrowedUnary[T, _IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]]]]] where Self.Value == List[T] and _CarrierCompatible[ListFamily, R]:
        """Sequence a zero-argument factory and keep its produced values."""
        comptime assert Self.Value == List[T]
        comptime assert _ErrorCompatible[Never, ListFamily.BindError[List[T], _BorrowedUnary[T, _IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]]]]]
        return Piped(_flat_map_as[Never, ListFamily, List[T], _BorrowedUnary[T, _IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]]]](_BorrowedUnary[T, _IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]]](_IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]](_NativeThunkRef[R, Never, C, False, o](Pointer(to=function)))), rebind_var[List[T]](self.value^)))

    def followed_by[T: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingThunk[R, X]](deinit self, ref[o] function: C) raises X -> Piped[ListFamily.Bound[List[T], _BorrowedUnary[T, _IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]]]]] where Self.Value == List[T] and _CarrierCompatible[ListFamily, R]:
        """Sequence a zero-argument factory and keep its produced values."""
        comptime assert Self.Value == List[T]
        comptime assert _ErrorCompatible[X, ListFamily.BindError[List[T], _BorrowedUnary[T, _IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]]]]]
        return Piped(_flat_map_as[X, ListFamily, List[T], _BorrowedUnary[T, _IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]]]](_BorrowedUnary[T, _IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]]](_IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]](_NativeThunkRef[R, X, C, True, o](Pointer(to=function)))), rebind_var[List[T]](self.value^)))

    def before[T: Movable & Deinitable, C: ThunkContract & Movable & Deinitable, //](deinit self, var function: C) raises C.Error -> Piped[ListFamily.Bound[List[T], _EffectRetain[T, ListFamily, _IgnoreInput[T, C]]]] where Self.Value == List[T] and _CarrierCompatible[ListFamily, C.Out]:
        """Sequence a zero-argument factory and retain each original value.

        Branches follow bind: no output skips the continuation; each produced
        success emits one output. Retained values must be Copyable for branching
        families. Single-use families move them. Native errors keep their types.

        Parameters:
            T: The source payload type, including origins.
            C: The callback, with its exact receiver and effect type.

        Args:
            function: The callback, consumed; repeatable wherever the source can branch.

        Returns:
            A pipeline holding the family result; deferred families retain callbacks until execution.

        Raises:
            The exact callback or family construction error.
        """
        comptime assert Self.Value == List[T]
        comptime assert _ErrorCompatible[C.Error, ListFamily.BindError[List[T], _EffectRetain[T, ListFamily, _IgnoreInput[T, C]]]]
        return Piped(_flat_map_as[C.Error, ListFamily, List[T], _EffectRetain[T, ListFamily, _IgnoreInput[T, C]]](_EffectRetain[T, ListFamily, _IgnoreInput[T, C]](_IgnoreInput[T, C](function^)), rebind_var[List[T]](self.value^)))

    def before[T: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, C: _Thunk[R]](deinit self, ref[o] function: C) raises Never -> Piped[ListFamily.Bound[List[T], _EffectRetain[T, ListFamily, _IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]]]]] where Self.Value == List[T] and _CarrierCompatible[ListFamily, R]:
        """Sequence a zero-argument factory and retain each original value."""
        comptime assert Self.Value == List[T]
        comptime assert _ErrorCompatible[Never, ListFamily.BindError[List[T], _EffectRetain[T, ListFamily, _IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]]]]]
        return Piped(_flat_map_as[Never, ListFamily, List[T], _EffectRetain[T, ListFamily, _IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]]]](_EffectRetain[T, ListFamily, _IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]]](_IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]](_NativeThunkRef[R, Never, C, False, o](Pointer(to=function)))), rebind_var[List[T]](self.value^)))

    def before[T: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingThunk[R, X]](deinit self, ref[o] function: C) raises X -> Piped[ListFamily.Bound[List[T], _EffectRetain[T, ListFamily, _IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]]]]] where Self.Value == List[T] and _CarrierCompatible[ListFamily, R]:
        """Sequence a zero-argument factory and retain each original value."""
        comptime assert Self.Value == List[T]
        comptime assert _ErrorCompatible[X, ListFamily.BindError[List[T], _EffectRetain[T, ListFamily, _IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]]]]]
        return Piped(_flat_map_as[X, ListFamily, List[T], _EffectRetain[T, ListFamily, _IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]]]](_EffectRetain[T, ListFamily, _IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]]](_IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]](_NativeThunkRef[R, X, C, True, o](Pointer(to=function)))), rebind_var[List[T]](self.value^)))

    def flat_tap[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, //](deinit self, var function: C) raises C.Failure -> Piped[OptionalFamily.Bound[Optional[T], _EffectRetain[T, OptionalFamily, C]]] where Self.Value == Optional[T] and C.Payload == T and _CarrierCompatible[OptionalFamily, C.Result]:
        """Sequence a borrowing effectful callback and retain each original value.

        Branches follow bind: no output skips the continuation; each produced
        success emits one output. Retained values must be Copyable for branching
        families. Single-use families move them. Native errors keep their types.

        Parameters:
            T: The source payload type, including origins.
            C: The callback, with its exact receiver and effect type.

        Args:
            function: The callback, consumed; repeatable wherever the source can branch.

        Returns:
            A pipeline holding the family result; deferred families retain callbacks until execution.

        Raises:
            The exact callback or family construction error.
        """
        comptime assert Self.Value == Optional[T]
        comptime assert _ErrorCompatible[C.Failure, OptionalFamily.BindError[Optional[T], _EffectRetain[T, OptionalFamily, C]]]
        return Piped(_flat_map_as[C.Failure, OptionalFamily, Optional[T], _EffectRetain[T, OptionalFamily, C]](_EffectRetain[T, OptionalFamily, C](function^), rebind_var[Optional[T]](self.value^)))

    def flat_tap[T: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, C: _Borrowing[P, R]](deinit self, ref[o] function: C) raises Never -> Piped[OptionalFamily.Bound[Optional[T], _EffectRetain[T, OptionalFamily, _NativeBorrowRef[P, R, Never, C, False, o]]]] where Self.Value == Optional[T] and P == T and _CarrierCompatible[OptionalFamily, R]:
        """Sequence a borrowing effectful callback and retain each original value."""
        comptime assert Self.Value == Optional[T]
        comptime assert _ErrorCompatible[Never, OptionalFamily.BindError[Optional[T], _EffectRetain[T, OptionalFamily, _NativeBorrowRef[P, R, Never, C, False, o]]]]
        return Piped(_flat_map_as[Never, OptionalFamily, Optional[T], _EffectRetain[T, OptionalFamily, _NativeBorrowRef[P, R, Never, C, False, o]]](_EffectRetain[T, OptionalFamily, _NativeBorrowRef[P, R, Never, C, False, o]](_NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=function))), rebind_var[Optional[T]](self.value^)))

    def flat_tap[T: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X]](deinit self, ref[o] function: C) raises X -> Piped[OptionalFamily.Bound[Optional[T], _EffectRetain[T, OptionalFamily, _NativeBorrowRef[P, R, X, C, True, o]]]] where Self.Value == Optional[T] and P == T and _CarrierCompatible[OptionalFamily, R]:
        """Sequence a borrowing effectful callback and retain each original value."""
        comptime assert Self.Value == Optional[T]
        comptime assert _ErrorCompatible[X, OptionalFamily.BindError[Optional[T], _EffectRetain[T, OptionalFamily, _NativeBorrowRef[P, R, X, C, True, o]]]]
        return Piped(_flat_map_as[X, OptionalFamily, Optional[T], _EffectRetain[T, OptionalFamily, _NativeBorrowRef[P, R, X, C, True, o]]](_EffectRetain[T, OptionalFamily, _NativeBorrowRef[P, R, X, C, True, o]](_NativeBorrowRef[P, R, X, C, True, o](Pointer(to=function))), rebind_var[Optional[T]](self.value^)))

    def flat_pair_with[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, //](deinit self, var function: C) raises C.Failure -> Piped[OptionalFamily.Bound[Optional[T], _EffectRetain[T, OptionalFamily, C, False, True]]] where Self.Value == Optional[T] and C.Payload == T and _CarrierCompatible[OptionalFamily, C.Result]:
        """Sequence a borrowing effectful projection and pair each success with its original.

        Each successful projection emits (original, projected). Projected values
        are moved; only retained originals need Copyable when effects branch.


        Branches follow bind: no output skips the continuation; each produced
        success emits one output. Retained values must be Copyable for branching
        families. Single-use families move them. Native errors keep their types.

        Parameters:
            T: The source payload type, including origins.
            C: The callback, with its exact receiver and effect type.

        Args:
            function: The callback, consumed; repeatable wherever the source can branch.

        Returns:
            A pipeline holding the family result; deferred families retain callbacks until execution.

        Raises:
            The exact callback or family construction error.
        """
        comptime assert Self.Value == Optional[T]
        comptime assert _ErrorCompatible[C.Failure, OptionalFamily.BindError[Optional[T], _EffectRetain[T, OptionalFamily, C, False, True]]]
        return Piped(_flat_map_as[C.Failure, OptionalFamily, Optional[T], _EffectRetain[T, OptionalFamily, C, False, True]](_EffectRetain[T, OptionalFamily, C, False, True](function^), rebind_var[Optional[T]](self.value^)))

    def flat_pair_with[T: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, C: _Borrowing[P, R]](deinit self, ref[o] function: C) raises Never -> Piped[OptionalFamily.Bound[Optional[T], _EffectRetain[T, OptionalFamily, _NativeBorrowRef[P, R, Never, C, False, o], False, True]]] where Self.Value == Optional[T] and P == T and _CarrierCompatible[OptionalFamily, R]:
        """Sequence a borrowing effectful projection and pair each success with its original."""
        comptime assert Self.Value == Optional[T]
        comptime assert _ErrorCompatible[Never, OptionalFamily.BindError[Optional[T], _EffectRetain[T, OptionalFamily, _NativeBorrowRef[P, R, Never, C, False, o], False, True]]]
        return Piped(_flat_map_as[Never, OptionalFamily, Optional[T], _EffectRetain[T, OptionalFamily, _NativeBorrowRef[P, R, Never, C, False, o], False, True]](_EffectRetain[T, OptionalFamily, _NativeBorrowRef[P, R, Never, C, False, o], False, True](_NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=function))), rebind_var[Optional[T]](self.value^)))

    def flat_pair_with[T: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X]](deinit self, ref[o] function: C) raises X -> Piped[OptionalFamily.Bound[Optional[T], _EffectRetain[T, OptionalFamily, _NativeBorrowRef[P, R, X, C, True, o], False, True]]] where Self.Value == Optional[T] and P == T and _CarrierCompatible[OptionalFamily, R]:
        """Sequence a borrowing effectful projection and pair each success with its original."""
        comptime assert Self.Value == Optional[T]
        comptime assert _ErrorCompatible[X, OptionalFamily.BindError[Optional[T], _EffectRetain[T, OptionalFamily, _NativeBorrowRef[P, R, X, C, True, o], False, True]]]
        return Piped(_flat_map_as[X, OptionalFamily, Optional[T], _EffectRetain[T, OptionalFamily, _NativeBorrowRef[P, R, X, C, True, o], False, True]](_EffectRetain[T, OptionalFamily, _NativeBorrowRef[P, R, X, C, True, o], False, True](_NativeBorrowRef[P, R, X, C, True, o](Pointer(to=function))), rebind_var[Optional[T]](self.value^)))

    def followed_by[T: Movable & Deinitable, C: ThunkContract & Movable & Deinitable, //](deinit self, var function: C) raises C.Error -> Piped[OptionalFamily.Bound[Optional[T], _BorrowedUnary[T, _IgnoreInput[T, C]]]] where Self.Value == Optional[T] and _CarrierCompatible[OptionalFamily, C.Out]:
        """Sequence a zero-argument factory and keep its produced values.

        Branches follow bind: no output skips the continuation; each produced
        success emits one output. Retained values must be Copyable for branching
        families. Single-use families move them. Native errors keep their types.

        Parameters:
            T: The source payload type, including origins.
            C: The callback, with its exact receiver and effect type.

        Args:
            function: The callback, consumed; repeatable wherever the source can branch.

        Returns:
            A pipeline holding the family result; deferred families retain callbacks until execution.

        Raises:
            The exact callback or family construction error.
        """
        comptime assert Self.Value == Optional[T]
        comptime assert _ErrorCompatible[C.Error, OptionalFamily.BindError[Optional[T], _BorrowedUnary[T, _IgnoreInput[T, C]]]]
        return Piped(_flat_map_as[C.Error, OptionalFamily, Optional[T], _BorrowedUnary[T, _IgnoreInput[T, C]]](_BorrowedUnary[T, _IgnoreInput[T, C]](_IgnoreInput[T, C](function^)), rebind_var[Optional[T]](self.value^)))

    def followed_by[T: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, C: _Thunk[R]](deinit self, ref[o] function: C) raises Never -> Piped[OptionalFamily.Bound[Optional[T], _BorrowedUnary[T, _IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]]]]] where Self.Value == Optional[T] and _CarrierCompatible[OptionalFamily, R]:
        """Sequence a zero-argument factory and keep its produced values."""
        comptime assert Self.Value == Optional[T]
        comptime assert _ErrorCompatible[Never, OptionalFamily.BindError[Optional[T], _BorrowedUnary[T, _IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]]]]]
        return Piped(_flat_map_as[Never, OptionalFamily, Optional[T], _BorrowedUnary[T, _IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]]]](_BorrowedUnary[T, _IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]]](_IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]](_NativeThunkRef[R, Never, C, False, o](Pointer(to=function)))), rebind_var[Optional[T]](self.value^)))

    def followed_by[T: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingThunk[R, X]](deinit self, ref[o] function: C) raises X -> Piped[OptionalFamily.Bound[Optional[T], _BorrowedUnary[T, _IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]]]]] where Self.Value == Optional[T] and _CarrierCompatible[OptionalFamily, R]:
        """Sequence a zero-argument factory and keep its produced values."""
        comptime assert Self.Value == Optional[T]
        comptime assert _ErrorCompatible[X, OptionalFamily.BindError[Optional[T], _BorrowedUnary[T, _IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]]]]]
        return Piped(_flat_map_as[X, OptionalFamily, Optional[T], _BorrowedUnary[T, _IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]]]](_BorrowedUnary[T, _IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]]](_IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]](_NativeThunkRef[R, X, C, True, o](Pointer(to=function)))), rebind_var[Optional[T]](self.value^)))

    def before[T: Movable & Deinitable, C: ThunkContract & Movable & Deinitable, //](deinit self, var function: C) raises C.Error -> Piped[OptionalFamily.Bound[Optional[T], _EffectRetain[T, OptionalFamily, _IgnoreInput[T, C]]]] where Self.Value == Optional[T] and _CarrierCompatible[OptionalFamily, C.Out]:
        """Sequence a zero-argument factory and retain each original value.

        Branches follow bind: no output skips the continuation; each produced
        success emits one output. Retained values must be Copyable for branching
        families. Single-use families move them. Native errors keep their types.

        Parameters:
            T: The source payload type, including origins.
            C: The callback, with its exact receiver and effect type.

        Args:
            function: The callback, consumed; repeatable wherever the source can branch.

        Returns:
            A pipeline holding the family result; deferred families retain callbacks until execution.

        Raises:
            The exact callback or family construction error.
        """
        comptime assert Self.Value == Optional[T]
        comptime assert _ErrorCompatible[C.Error, OptionalFamily.BindError[Optional[T], _EffectRetain[T, OptionalFamily, _IgnoreInput[T, C]]]]
        return Piped(_flat_map_as[C.Error, OptionalFamily, Optional[T], _EffectRetain[T, OptionalFamily, _IgnoreInput[T, C]]](_EffectRetain[T, OptionalFamily, _IgnoreInput[T, C]](_IgnoreInput[T, C](function^)), rebind_var[Optional[T]](self.value^)))

    def before[T: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, C: _Thunk[R]](deinit self, ref[o] function: C) raises Never -> Piped[OptionalFamily.Bound[Optional[T], _EffectRetain[T, OptionalFamily, _IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]]]]] where Self.Value == Optional[T] and _CarrierCompatible[OptionalFamily, R]:
        """Sequence a zero-argument factory and retain each original value."""
        comptime assert Self.Value == Optional[T]
        comptime assert _ErrorCompatible[Never, OptionalFamily.BindError[Optional[T], _EffectRetain[T, OptionalFamily, _IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]]]]]
        return Piped(_flat_map_as[Never, OptionalFamily, Optional[T], _EffectRetain[T, OptionalFamily, _IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]]]](_EffectRetain[T, OptionalFamily, _IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]]](_IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]](_NativeThunkRef[R, Never, C, False, o](Pointer(to=function)))), rebind_var[Optional[T]](self.value^)))

    def before[T: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, X: Movable & Deinitable, C: _RaisingThunk[R, X]](deinit self, ref[o] function: C) raises X -> Piped[OptionalFamily.Bound[Optional[T], _EffectRetain[T, OptionalFamily, _IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]]]]] where Self.Value == Optional[T] and _CarrierCompatible[OptionalFamily, R]:
        """Sequence a zero-argument factory and retain each original value."""
        comptime assert Self.Value == Optional[T]
        comptime assert _ErrorCompatible[X, OptionalFamily.BindError[Optional[T], _EffectRetain[T, OptionalFamily, _IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]]]]]
        return Piped(_flat_map_as[X, OptionalFamily, Optional[T], _EffectRetain[T, OptionalFamily, _IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]]]](_EffectRetain[T, OptionalFamily, _IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]]](_IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]](_NativeThunkRef[R, X, C, True, o](Pointer(to=function)))), rebind_var[Optional[T]](self.value^)))

    def flat_tap[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, Failure: Movable & Deinitable, //](deinit self, var function: C) raises C.Failure -> Piped[ResultFamily[Failure].Bound[Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], C]]] where Self.Value == Result[T, Failure] and C.Payload == T and _CarrierCompatible[ResultFamily[Failure], C.Result]:
        """Sequence a borrowing effectful callback and retain each original value.

        Branches follow bind: no output skips the continuation; each produced
        success emits one output. Retained values must be Copyable for branching
        families. Single-use families move them. Native errors keep their types.

        Parameters:
            T: The source payload type, including origins.
            C: The callback, with its exact receiver and effect type.
            Failure: The stored Result error type.

        Args:
            function: The callback, consumed; repeatable wherever the source can branch.

        Returns:
            A pipeline holding the family result; deferred families retain callbacks until execution.

        Raises:
            The exact callback or family construction error.
        """
        comptime assert Self.Value == Result[T, Failure]
        comptime assert _ErrorCompatible[C.Failure, ResultFamily[Failure].BindError[Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], C]]]
        return Piped(_flat_map_as[C.Failure, ResultFamily[Failure], Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], C]](_EffectRetain[T, ResultFamily[Failure], C](function^), rebind_var[Result[T, Failure]](self.value^)))

    def flat_tap[T: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Failure: Movable & Deinitable, //, C: _Borrowing[P, R]](deinit self, ref[o] function: C) raises Never -> Piped[ResultFamily[Failure].Bound[Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], _NativeBorrowRef[P, R, Never, C, False, o]]]] where Self.Value == Result[T, Failure] and P == T and _CarrierCompatible[ResultFamily[Failure], R]:
        """Sequence a borrowing effectful callback and retain each original value."""
        comptime assert Self.Value == Result[T, Failure]
        comptime assert _ErrorCompatible[Never, ResultFamily[Failure].BindError[Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], _NativeBorrowRef[P, R, Never, C, False, o]]]]
        return Piped(_flat_map_as[Never, ResultFamily[Failure], Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], _NativeBorrowRef[P, R, Never, C, False, o]]](_EffectRetain[T, ResultFamily[Failure], _NativeBorrowRef[P, R, Never, C, False, o]](_NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=function))), rebind_var[Result[T, Failure]](self.value^)))

    def flat_tap[T: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Failure: Movable & Deinitable, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X]](deinit self, ref[o] function: C) raises X -> Piped[ResultFamily[Failure].Bound[Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], _NativeBorrowRef[P, R, X, C, True, o]]]] where Self.Value == Result[T, Failure] and P == T and _CarrierCompatible[ResultFamily[Failure], R]:
        """Sequence a borrowing effectful callback and retain each original value."""
        comptime assert Self.Value == Result[T, Failure]
        comptime assert _ErrorCompatible[X, ResultFamily[Failure].BindError[Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], _NativeBorrowRef[P, R, X, C, True, o]]]]
        return Piped(_flat_map_as[X, ResultFamily[Failure], Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], _NativeBorrowRef[P, R, X, C, True, o]]](_EffectRetain[T, ResultFamily[Failure], _NativeBorrowRef[P, R, X, C, True, o]](_NativeBorrowRef[P, R, X, C, True, o](Pointer(to=function))), rebind_var[Result[T, Failure]](self.value^)))

    def flat_pair_with[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, Failure: Movable & Deinitable, //](deinit self, var function: C) raises C.Failure -> Piped[ResultFamily[Failure].Bound[Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], C, False, True]]] where Self.Value == Result[T, Failure] and C.Payload == T and _CarrierCompatible[ResultFamily[Failure], C.Result]:
        """Sequence a borrowing effectful projection and pair each success with its original.

        Each successful projection emits (original, projected). Projected values
        are moved; only retained originals need Copyable when effects branch.


        Branches follow bind: no output skips the continuation; each produced
        success emits one output. Retained values must be Copyable for branching
        families. Single-use families move them. Native errors keep their types.

        Parameters:
            T: The source payload type, including origins.
            C: The callback, with its exact receiver and effect type.
            Failure: The stored Result error type.

        Args:
            function: The callback, consumed; repeatable wherever the source can branch.

        Returns:
            A pipeline holding the family result; deferred families retain callbacks until execution.

        Raises:
            The exact callback or family construction error.
        """
        comptime assert Self.Value == Result[T, Failure]
        comptime assert _ErrorCompatible[C.Failure, ResultFamily[Failure].BindError[Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], C, False, True]]]
        return Piped(_flat_map_as[C.Failure, ResultFamily[Failure], Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], C, False, True]](_EffectRetain[T, ResultFamily[Failure], C, False, True](function^), rebind_var[Result[T, Failure]](self.value^)))

    def flat_pair_with[T: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Failure: Movable & Deinitable, //, C: _Borrowing[P, R]](deinit self, ref[o] function: C) raises Never -> Piped[ResultFamily[Failure].Bound[Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], _NativeBorrowRef[P, R, Never, C, False, o], False, True]]] where Self.Value == Result[T, Failure] and P == T and _CarrierCompatible[ResultFamily[Failure], R]:
        """Sequence a borrowing effectful projection and pair each success with its original."""
        comptime assert Self.Value == Result[T, Failure]
        comptime assert _ErrorCompatible[Never, ResultFamily[Failure].BindError[Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], _NativeBorrowRef[P, R, Never, C, False, o], False, True]]]
        return Piped(_flat_map_as[Never, ResultFamily[Failure], Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], _NativeBorrowRef[P, R, Never, C, False, o], False, True]](_EffectRetain[T, ResultFamily[Failure], _NativeBorrowRef[P, R, Never, C, False, o], False, True](_NativeBorrowRef[P, R, Never, C, False, o](Pointer(to=function))), rebind_var[Result[T, Failure]](self.value^)))

    def flat_pair_with[T: Movable & Deinitable, P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Failure: Movable & Deinitable, //, X: Movable & Deinitable, C: _RaisingBorrowing[P, R, X]](deinit self, ref[o] function: C) raises X -> Piped[ResultFamily[Failure].Bound[Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], _NativeBorrowRef[P, R, X, C, True, o], False, True]]] where Self.Value == Result[T, Failure] and P == T and _CarrierCompatible[ResultFamily[Failure], R]:
        """Sequence a borrowing effectful projection and pair each success with its original."""
        comptime assert Self.Value == Result[T, Failure]
        comptime assert _ErrorCompatible[X, ResultFamily[Failure].BindError[Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], _NativeBorrowRef[P, R, X, C, True, o], False, True]]]
        return Piped(_flat_map_as[X, ResultFamily[Failure], Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], _NativeBorrowRef[P, R, X, C, True, o], False, True]](_EffectRetain[T, ResultFamily[Failure], _NativeBorrowRef[P, R, X, C, True, o], False, True](_NativeBorrowRef[P, R, X, C, True, o](Pointer(to=function))), rebind_var[Result[T, Failure]](self.value^)))

    def followed_by[T: Movable & Deinitable, C: ThunkContract & Movable & Deinitable, Failure: Movable & Deinitable, //](deinit self, var function: C) raises C.Error -> Piped[ResultFamily[Failure].Bound[Result[T, Failure], _BorrowedUnary[T, _IgnoreInput[T, C]]]] where Self.Value == Result[T, Failure] and _CarrierCompatible[ResultFamily[Failure], C.Out]:
        """Sequence a zero-argument factory and keep its produced values.

        Branches follow bind: no output skips the continuation; each produced
        success emits one output. Retained values must be Copyable for branching
        families. Single-use families move them. Native errors keep their types.

        Parameters:
            T: The source payload type, including origins.
            C: The callback, with its exact receiver and effect type.
            Failure: The stored Result error type.

        Args:
            function: The callback, consumed; repeatable wherever the source can branch.

        Returns:
            A pipeline holding the family result; deferred families retain callbacks until execution.

        Raises:
            The exact callback or family construction error.
        """
        comptime assert Self.Value == Result[T, Failure]
        comptime assert _ErrorCompatible[C.Error, ResultFamily[Failure].BindError[Result[T, Failure], _BorrowedUnary[T, _IgnoreInput[T, C]]]]
        return Piped(_flat_map_as[C.Error, ResultFamily[Failure], Result[T, Failure], _BorrowedUnary[T, _IgnoreInput[T, C]]](_BorrowedUnary[T, _IgnoreInput[T, C]](_IgnoreInput[T, C](function^)), rebind_var[Result[T, Failure]](self.value^)))

    def followed_by[T: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, Failure: Movable & Deinitable, //, C: _Thunk[R]](deinit self, ref[o] function: C) raises Never -> Piped[ResultFamily[Failure].Bound[Result[T, Failure], _BorrowedUnary[T, _IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]]]]] where Self.Value == Result[T, Failure] and _CarrierCompatible[ResultFamily[Failure], R]:
        """Sequence a zero-argument factory and keep its produced values."""
        comptime assert Self.Value == Result[T, Failure]
        comptime assert _ErrorCompatible[Never, ResultFamily[Failure].BindError[Result[T, Failure], _BorrowedUnary[T, _IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]]]]]
        return Piped(_flat_map_as[Never, ResultFamily[Failure], Result[T, Failure], _BorrowedUnary[T, _IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]]]](_BorrowedUnary[T, _IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]]](_IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]](_NativeThunkRef[R, Never, C, False, o](Pointer(to=function)))), rebind_var[Result[T, Failure]](self.value^)))

    def followed_by[T: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, Failure: Movable & Deinitable, //, X: Movable & Deinitable, C: _RaisingThunk[R, X]](deinit self, ref[o] function: C) raises X -> Piped[ResultFamily[Failure].Bound[Result[T, Failure], _BorrowedUnary[T, _IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]]]]] where Self.Value == Result[T, Failure] and _CarrierCompatible[ResultFamily[Failure], R]:
        """Sequence a zero-argument factory and keep its produced values."""
        comptime assert Self.Value == Result[T, Failure]
        comptime assert _ErrorCompatible[X, ResultFamily[Failure].BindError[Result[T, Failure], _BorrowedUnary[T, _IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]]]]]
        return Piped(_flat_map_as[X, ResultFamily[Failure], Result[T, Failure], _BorrowedUnary[T, _IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]]]](_BorrowedUnary[T, _IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]]](_IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]](_NativeThunkRef[R, X, C, True, o](Pointer(to=function)))), rebind_var[Result[T, Failure]](self.value^)))

    def before[T: Movable & Deinitable, C: ThunkContract & Movable & Deinitable, Failure: Movable & Deinitable, //](deinit self, var function: C) raises C.Error -> Piped[ResultFamily[Failure].Bound[Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], _IgnoreInput[T, C]]]] where Self.Value == Result[T, Failure] and _CarrierCompatible[ResultFamily[Failure], C.Out]:
        """Sequence a zero-argument factory and retain each original value.

        Branches follow bind: no output skips the continuation; each produced
        success emits one output. Retained values must be Copyable for branching
        families. Single-use families move them. Native errors keep their types.

        Parameters:
            T: The source payload type, including origins.
            C: The callback, with its exact receiver and effect type.
            Failure: The stored Result error type.

        Args:
            function: The callback, consumed; repeatable wherever the source can branch.

        Returns:
            A pipeline holding the family result; deferred families retain callbacks until execution.

        Raises:
            The exact callback or family construction error.
        """
        comptime assert Self.Value == Result[T, Failure]
        comptime assert _ErrorCompatible[C.Error, ResultFamily[Failure].BindError[Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], _IgnoreInput[T, C]]]]
        return Piped(_flat_map_as[C.Error, ResultFamily[Failure], Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], _IgnoreInput[T, C]]](_EffectRetain[T, ResultFamily[Failure], _IgnoreInput[T, C]](_IgnoreInput[T, C](function^)), rebind_var[Result[T, Failure]](self.value^)))

    def before[T: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, Failure: Movable & Deinitable, //, C: _Thunk[R]](deinit self, ref[o] function: C) raises Never -> Piped[ResultFamily[Failure].Bound[Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], _IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]]]]] where Self.Value == Result[T, Failure] and _CarrierCompatible[ResultFamily[Failure], R]:
        """Sequence a zero-argument factory and retain each original value."""
        comptime assert Self.Value == Result[T, Failure]
        comptime assert _ErrorCompatible[Never, ResultFamily[Failure].BindError[Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], _IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]]]]]
        return Piped(_flat_map_as[Never, ResultFamily[Failure], Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], _IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]]]](_EffectRetain[T, ResultFamily[Failure], _IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]]](_IgnoreInput[T, _NativeThunkRef[R, Never, C, False, o]](_NativeThunkRef[R, Never, C, False, o](Pointer(to=function)))), rebind_var[Result[T, Failure]](self.value^)))

    def before[T: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, Failure: Movable & Deinitable, //, X: Movable & Deinitable, C: _RaisingThunk[R, X]](deinit self, ref[o] function: C) raises X -> Piped[ResultFamily[Failure].Bound[Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], _IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]]]]] where Self.Value == Result[T, Failure] and _CarrierCompatible[ResultFamily[Failure], R]:
        """Sequence a zero-argument factory and retain each original value."""
        comptime assert Self.Value == Result[T, Failure]
        comptime assert _ErrorCompatible[X, ResultFamily[Failure].BindError[Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], _IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]]]]]
        return Piped(_flat_map_as[X, ResultFamily[Failure], Result[T, Failure], _EffectRetain[T, ResultFamily[Failure], _IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]]]](_EffectRetain[T, ResultFamily[Failure], _IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]]](_IgnoreInput[T, _NativeThunkRef[R, X, C, True, o]](_NativeThunkRef[R, X, C, True, o](Pointer(to=function)))), rebind_var[Result[T, Failure]](self.value^)))

    def map[T: Movable & Deinitable, U: Movable & Deinitable, //, F: def(var T) -> U](
        deinit self, ref function: F
    ) -> Piped[List[U]] where Self.Value == List[T]:
        """Map List payloads immediately, preserving the native container."""
        comptime assert Self.Value == List[T]
        return Piped(_family_map[ListFamily](function, rebind_var[List[T]](self.value^)))

    def map[T: Movable & Deinitable, U: Movable & Deinitable, //, E: Movable & Deinitable, F: def(var T) raises E -> U](
        deinit self, ref function: F
    ) raises E -> Piped[List[U]] where Self.Value == List[T]:
        """Map List payloads immediately, preserving the native container."""
        comptime assert Self.Value == List[T]
        return Piped(_family_map[ListFamily, X=E](function, rebind_var[List[T]](self.value^)))

    def map[F: UnaryContract & Movable & Deinitable](
        deinit self, var function: F
    ) raises F.Error -> Piped[List[F.Out]] where Self.Value == List[F.Arg] and RepeatableUnary[F]:
        """Map List payloads with an owned library callback."""
        comptime assert Self.Value == List[F.Arg]
        return Piped(ListFamily.map(function^, rebind_var[List[F.Arg]](self.value^)))

    def map[F: _UnaryViewable, o: ImmOrigin](
        deinit self, ref[o] function: F
    ) raises F._View[o].Error -> Piped[List[F._View[o].Out]] where Self.Value == List[F._View[o].Arg]:
        """Map List payloads with a borrowed callable view."""
        comptime assert Self.Value == List[F._View[o].Arg]
        return Piped(_family_map[ListFamily](function._unary_view(), rebind_var[List[F._View[o].Arg]](self.value^)))

    def map[T: Movable & Deinitable, U: Movable & Deinitable, N: Int, //, F: def(var T) -> U](
        deinit self, ref function: F
    ) -> Piped[Array[U, N]] where Self.Value == Array[T, N]:
        """Map Array payloads immediately, preserving the native container."""
        comptime assert Self.Value == Array[T, N]
        return Piped(_family_map[_ArrayFamily[N]](function, rebind_var[Array[T, N]](self.value^)))

    def map[T: Movable & Deinitable, U: Movable & Deinitable, N: Int, //, E: Movable & Deinitable, F: def(var T) raises E -> U](
        deinit self, ref function: F
    ) raises E -> Piped[Array[U, N]] where Self.Value == Array[T, N]:
        """Map Array payloads immediately, preserving the native container."""
        comptime assert Self.Value == Array[T, N]
        return Piped(_family_map[_ArrayFamily[N], X=E](function, rebind_var[Array[T, N]](self.value^)))

    def map[F: UnaryContract & Movable & Deinitable, N: Int](
        deinit self, var function: F
    ) raises F.Error -> Piped[Array[F.Out, N]] where Self.Value == Array[F.Arg, N] and _MapCompatible[_ArrayFamily[N], Array[F.Arg, N], F]:
        """Map Array payloads with an owned library callback."""
        comptime assert Self.Value == Array[F.Arg, N]
        return Piped(_ArrayFamily[N].map(function^, rebind_var[Array[F.Arg, N]](self.value^)))

    def map[F: _UnaryViewable, o: ImmOrigin, N: Int](
        deinit self, ref[o] function: F
    ) raises F._View[o].Error -> Piped[Array[F._View[o].Out, N]] where Self.Value == Array[F._View[o].Arg, N]:
        """Map Array payloads with a borrowed callable view."""
        comptime assert Self.Value == Array[F._View[o].Arg, N]
        return Piped(_family_map[_ArrayFamily[N]](function._unary_view(), rebind_var[Array[F._View[o].Arg, N]](self.value^)))

    def map[T: Movable & Deinitable, U: Movable & Deinitable, //, F: def(var T) -> U](
        deinit self, ref function: F
    ) -> Piped[Deque[U]] where Self.Value == Deque[T]:
        """Map Deque payloads immediately, preserving the native container."""
        comptime assert Self.Value == Deque[T]
        return Piped(_family_map[_DequeFamily](function, rebind_var[Deque[T]](self.value^)))

    def map[T: Movable & Deinitable, U: Movable & Deinitable, //, E: Movable & Deinitable, F: def(var T) raises E -> U](
        deinit self, ref function: F
    ) raises E -> Piped[Deque[U]] where Self.Value == Deque[T]:
        """Map Deque payloads immediately, preserving the native container."""
        comptime assert Self.Value == Deque[T]
        return Piped(_family_map[_DequeFamily, X=E](function, rebind_var[Deque[T]](self.value^)))

    def map[F: UnaryContract & Movable & Deinitable](
        deinit self, var function: F
    ) raises F.Error -> Piped[Deque[F.Out]] where Self.Value == Deque[F.Arg] and _MapCompatible[_DequeFamily, Deque[F.Arg], F]:
        """Map Deque payloads with an owned library callback."""
        comptime assert Self.Value == Deque[F.Arg]
        return Piped(_DequeFamily.map(function^, rebind_var[Deque[F.Arg]](self.value^)))

    def map[F: _UnaryViewable, o: ImmOrigin](
        deinit self, ref[o] function: F
    ) raises F._View[o].Error -> Piped[Deque[F._View[o].Out]] where Self.Value == Deque[F._View[o].Arg]:
        """Map Deque payloads with a borrowed callable view."""
        comptime assert Self.Value == Deque[F._View[o].Arg]
        return Piped(_family_map[_DequeFamily](function._unary_view(), rebind_var[Deque[F._View[o].Arg]](self.value^)))

    def map[T: Movable & Deinitable, U: Movable & Deinitable, //, F: def(var T) -> U](
        deinit self, ref function: F
    ) -> Piped[LinkedList[U]] where Self.Value == LinkedList[T]:
        """Map LinkedList payloads immediately, preserving the native container."""
        comptime assert Self.Value == LinkedList[T]
        return Piped(_family_map[_LinkedListFamily](function, rebind_var[LinkedList[T]](self.value^)))

    def map[T: Movable & Deinitable, U: Movable & Deinitable, //, E: Movable & Deinitable, F: def(var T) raises E -> U](
        deinit self, ref function: F
    ) raises E -> Piped[LinkedList[U]] where Self.Value == LinkedList[T]:
        """Map LinkedList payloads immediately, preserving the native container."""
        comptime assert Self.Value == LinkedList[T]
        return Piped(_family_map[_LinkedListFamily, X=E](function, rebind_var[LinkedList[T]](self.value^)))

    def map[F: UnaryContract & Movable & Deinitable](
        deinit self, var function: F
    ) raises F.Error -> Piped[LinkedList[F.Out]] where Self.Value == LinkedList[F.Arg] and _MapCompatible[_LinkedListFamily, LinkedList[F.Arg], F]:
        """Map LinkedList payloads with an owned library callback."""
        comptime assert Self.Value == LinkedList[F.Arg]
        return Piped(_LinkedListFamily.map(function^, rebind_var[LinkedList[F.Arg]](self.value^)))

    def map[F: _UnaryViewable, o: ImmOrigin](
        deinit self, ref[o] function: F
    ) raises F._View[o].Error -> Piped[LinkedList[F._View[o].Out]] where Self.Value == LinkedList[F._View[o].Arg]:
        """Map LinkedList payloads with a borrowed callable view."""
        comptime assert Self.Value == LinkedList[F._View[o].Arg]
        return Piped(_family_map[_LinkedListFamily](function._unary_view(), rebind_var[LinkedList[F._View[o].Arg]](self.value^)))

    def map[T: Movable & Deinitable, U: Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //, F: def(var T) -> U](
        deinit self, ref function: F
    ) -> Piped[Dict[K, U, H]] where Self.Value == Dict[K, T, H]:
        """Map Dict payloads immediately, preserving the native container."""
        comptime assert Self.Value == Dict[K, T, H]
        return Piped(_family_map[_DictFamily[K, T, H]](function, rebind_var[Dict[K, T, H]](self.value^)))

    def map[T: Movable & Deinitable, U: Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //, E: Movable & Deinitable, F: def(var T) raises E -> U](
        deinit self, ref function: F
    ) raises E -> Piped[Dict[K, U, H]] where Self.Value == Dict[K, T, H]:
        """Map Dict payloads immediately, preserving the native container."""
        comptime assert Self.Value == Dict[K, T, H]
        return Piped(_family_map[_DictFamily[K, T, H], X=E](function, rebind_var[Dict[K, T, H]](self.value^)))

    def map[F: UnaryContract & Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable](
        deinit self, var function: F
    ) raises F.Error -> Piped[Dict[K, F.Out, H]] where Self.Value == Dict[K, F.Arg, H] and _MapCompatible[_DictFamily[K, F.Arg, H], Dict[K, F.Arg, H], F]:
        """Map Dict payloads with an owned library callback."""
        comptime assert Self.Value == Dict[K, F.Arg, H]
        return Piped(_DictFamily[K, F.Arg, H].map(function^, rebind_var[Dict[K, F.Arg, H]](self.value^)))

    def map[F: _UnaryViewable, o: ImmOrigin, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable](
        deinit self, ref[o] function: F
    ) raises F._View[o].Error -> Piped[Dict[K, F._View[o].Out, H]] where Self.Value == Dict[K, F._View[o].Arg, H]:
        """Map Dict payloads with a borrowed callable view."""
        comptime assert Self.Value == Dict[K, F._View[o].Arg, H]
        return Piped(_family_map[_DictFamily[K, F._View[o].Arg, H]](function._unary_view(), rebind_var[Dict[K, F._View[o].Arg, H]](self.value^)))

    def map[T: Movable & Deinitable, U: Movable & Deinitable, //, F: def(var T) -> U](
        deinit self, ref function: F
    ) -> Piped[StringDict[U]] where Self.Value == StringDict[T]:
        """Map StringDict payloads immediately, preserving the native container."""
        comptime assert Self.Value == StringDict[T]
        return Piped(_family_map[_StringDictFamily[T]](function, rebind_var[StringDict[T]](self.value^)))

    def map[T: Movable & Deinitable, U: Movable & Deinitable, //, E: Movable & Deinitable, F: def(var T) raises E -> U](
        deinit self, ref function: F
    ) raises E -> Piped[StringDict[U]] where Self.Value == StringDict[T]:
        """Map StringDict payloads immediately, preserving the native container."""
        comptime assert Self.Value == StringDict[T]
        return Piped(_family_map[_StringDictFamily[T], X=E](function, rebind_var[StringDict[T]](self.value^)))

    def map[F: UnaryContract & Movable & Deinitable](
        deinit self, var function: F
    ) raises F.Error -> Piped[StringDict[F.Out]] where Self.Value == StringDict[F.Arg] and _MapCompatible[_StringDictFamily[F.Arg], StringDict[F.Arg], F]:
        """Map StringDict payloads with an owned library callback."""
        comptime assert Self.Value == StringDict[F.Arg]
        return Piped(_StringDictFamily[F.Arg].map(function^, rebind_var[StringDict[F.Arg]](self.value^)))

    def map[F: _UnaryViewable, o: ImmOrigin](
        deinit self, ref[o] function: F
    ) raises F._View[o].Error -> Piped[StringDict[F._View[o].Out]] where Self.Value == StringDict[F._View[o].Arg]:
        """Map StringDict payloads with a borrowed callable view."""
        comptime assert Self.Value == StringDict[F._View[o].Arg]
        return Piped(_family_map[_StringDictFamily[F._View[o].Arg]](function._unary_view(), rebind_var[StringDict[F._View[o].Arg]](self.value^)))

    def map[T: Movable & Deinitable, U: Movable & Deinitable, //, F: def(var T) -> U](
        deinit self, ref function: F
    ) -> Piped[Optional[U]] where Self.Value == Optional[T]:
        """Map Optional payloads immediately, preserving the native container."""
        comptime assert Self.Value == Optional[T]
        return Piped(_family_map[OptionalFamily](function, rebind_var[Optional[T]](self.value^)))

    def map[T: Movable & Deinitable, U: Movable & Deinitable, //, E: Movable & Deinitable, F: def(var T) raises E -> U](
        deinit self, ref function: F
    ) raises E -> Piped[Optional[U]] where Self.Value == Optional[T]:
        """Map Optional payloads immediately, preserving the native container."""
        comptime assert Self.Value == Optional[T]
        return Piped(_family_map[OptionalFamily, X=E](function, rebind_var[Optional[T]](self.value^)))

    def map[F: UnaryContract & Movable & Deinitable](
        deinit self, var function: F
    ) raises F.Error -> Piped[Optional[F.Out]] where Self.Value == Optional[F.Arg] and _MapCompatible[OptionalFamily, Optional[F.Arg], F]:
        """Map Optional payloads with an owned library callback."""
        comptime assert Self.Value == Optional[F.Arg]
        return Piped(OptionalFamily.map(function^, rebind_var[Optional[F.Arg]](self.value^)))

    def map[F: _UnaryViewable, o: ImmOrigin](
        deinit self, ref[o] function: F
    ) raises F._View[o].Error -> Piped[Optional[F._View[o].Out]] where Self.Value == Optional[F._View[o].Arg]:
        """Map Optional payloads with a borrowed callable view."""
        comptime assert Self.Value == Optional[F._View[o].Arg]
        return Piped(_family_map[OptionalFamily](function._unary_view(), rebind_var[Optional[F._View[o].Arg]](self.value^)))

    def map[T: Movable & Deinitable, U: Movable & Deinitable, Failure: Movable & Deinitable, //, F: def(var T) -> U](
        deinit self, ref function: F
    ) -> Piped[Result[U, Failure]] where Self.Value == Result[T, Failure]:
        """Map Result payloads immediately, preserving the native container."""
        comptime assert Self.Value == Result[T, Failure]
        return Piped(_family_map[ResultFamily[Failure]](function, rebind_var[Result[T, Failure]](self.value^)))

    def map[T: Movable & Deinitable, U: Movable & Deinitable, Failure: Movable & Deinitable, //, E: Movable & Deinitable, F: def(var T) raises E -> U](
        deinit self, ref function: F
    ) raises E -> Piped[Result[U, Failure]] where Self.Value == Result[T, Failure]:
        """Map Result payloads immediately, preserving the native container."""
        comptime assert Self.Value == Result[T, Failure]
        return Piped(_family_map[ResultFamily[Failure], X=E](function, rebind_var[Result[T, Failure]](self.value^)))

    def map[F: UnaryContract & Movable & Deinitable, Failure: Movable & Deinitable](
        deinit self, var function: F
    ) raises F.Error -> Piped[Result[F.Out, Failure]] where Self.Value == Result[F.Arg, Failure] and _MapCompatible[ResultFamily[Failure], Result[F.Arg, Failure], F]:
        """Map Result payloads with an owned library callback."""
        comptime assert Self.Value == Result[F.Arg, Failure]
        return Piped(ResultFamily[Failure].map(function^, rebind_var[Result[F.Arg, Failure]](self.value^)))

    def map[F: _UnaryViewable, o: ImmOrigin, Failure: Movable & Deinitable](
        deinit self, ref[o] function: F
    ) raises F._View[o].Error -> Piped[Result[F._View[o].Out, Failure]] where Self.Value == Result[F._View[o].Arg, Failure]:
        """Map Result payloads with a borrowed callable view."""
        comptime assert Self.Value == Result[F._View[o].Arg, Failure]
        return Piped(_family_map[ResultFamily[Failure]](function._unary_view(), rebind_var[Result[F._View[o].Arg, Failure]](self.value^)))

    def filter[T: Movable & Deinitable, R: Movable & Deinitable, //, F: def(T) -> R](
        deinit self, ref predicate: F
    ) -> Piped[List[T]] where R == Bool and Self.Value == List[T]:
        """Retain accepted List payloads immediately, preserving their container."""
        comptime assert Self.Value == List[T]
        return Piped(_family_filter[ListFamily](predicate, rebind_var[List[T]](self.value^)))

    def filter[T: Movable & Deinitable, R: Movable & Deinitable, //, E: Movable & Deinitable, F: def(T) raises E -> R](
        deinit self, ref predicate: F
    ) raises E -> Piped[List[T]] where R == Bool and Self.Value == List[T]:
        """Retain accepted List payloads immediately, preserving their container."""
        comptime assert Self.Value == List[T]
        return Piped(_family_filter[ListFamily, E=E](predicate, rebind_var[List[T]](self.value^)))

    def filter[C: BorrowCallContract & Movable & Deinitable](
        deinit self, var predicate: C
    ) raises C.Failure -> Piped[List[downcast[C.Payload, Movable & Deinitable]]] where conforms_to(C.Payload, Movable & Deinitable) and Self.Value == List[downcast[C.Payload, Movable & Deinitable]] and C.Result == Bool and RepeatableBorrow[C]:
        """Retain accepted List payloads with an owned library predicate."""
        comptime assert Self.Value == List[downcast[C.Payload, Movable & Deinitable]]
        return Piped(_family_filter[ListFamily](predicate^, rebind_var[List[downcast[C.Payload, Movable & Deinitable]]](self.value^)))

    def filter[C: _BorrowViewable, o: ImmOrigin](
        deinit self, ref[o] predicate: C
    ) raises C._BorrowView[o].Failure -> Piped[List[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]] where conforms_to(C._BorrowView[o].Payload, Movable & Deinitable) and Self.Value == List[downcast[C._BorrowView[o].Payload, Movable & Deinitable]] and C._BorrowView[o].Result == Bool:
        """Retain accepted List payloads with a shared library predicate."""
        comptime assert Self.Value == List[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]
        return Piped(_family_filter[ListFamily](predicate._borrow_view(), rebind_var[List[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]](self.value^)))

    def filter[T: Movable & Deinitable, R: Movable & Deinitable, //, F: def(T) -> R](
        deinit self, ref predicate: F
    ) -> Piped[Deque[T]] where R == Bool and Self.Value == Deque[T]:
        """Retain accepted Deque payloads immediately, preserving their container."""
        comptime assert Self.Value == Deque[T]
        return Piped(_family_filter[_DequeFamily](predicate, rebind_var[Deque[T]](self.value^)))

    def filter[T: Movable & Deinitable, R: Movable & Deinitable, //, E: Movable & Deinitable, F: def(T) raises E -> R](
        deinit self, ref predicate: F
    ) raises E -> Piped[Deque[T]] where R == Bool and Self.Value == Deque[T]:
        """Retain accepted Deque payloads immediately, preserving their container."""
        comptime assert Self.Value == Deque[T]
        return Piped(_family_filter[_DequeFamily, E=E](predicate, rebind_var[Deque[T]](self.value^)))

    def filter[C: BorrowCallContract & Movable & Deinitable](
        deinit self, var predicate: C
    ) raises C.Failure -> Piped[Deque[downcast[C.Payload, Movable & Deinitable]]] where conforms_to(C.Payload, Movable & Deinitable) and Self.Value == Deque[downcast[C.Payload, Movable & Deinitable]] and C.Result == Bool and RepeatableBorrow[C]:
        """Retain accepted Deque payloads with an owned library predicate."""
        comptime assert Self.Value == Deque[downcast[C.Payload, Movable & Deinitable]]
        return Piped(_family_filter[_DequeFamily](predicate^, rebind_var[Deque[downcast[C.Payload, Movable & Deinitable]]](self.value^)))

    def filter[C: _BorrowViewable, o: ImmOrigin](
        deinit self, ref[o] predicate: C
    ) raises C._BorrowView[o].Failure -> Piped[Deque[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]] where conforms_to(C._BorrowView[o].Payload, Movable & Deinitable) and Self.Value == Deque[downcast[C._BorrowView[o].Payload, Movable & Deinitable]] and C._BorrowView[o].Result == Bool:
        """Retain accepted Deque payloads with a shared library predicate."""
        comptime assert Self.Value == Deque[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]
        return Piped(_family_filter[_DequeFamily](predicate._borrow_view(), rebind_var[Deque[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]](self.value^)))

    def filter[T: Movable & Deinitable, R: Movable & Deinitable, //, F: def(T) -> R](
        deinit self, ref predicate: F
    ) -> Piped[LinkedList[T]] where R == Bool and Self.Value == LinkedList[T]:
        """Retain accepted LinkedList payloads immediately, preserving their container."""
        comptime assert Self.Value == LinkedList[T]
        return Piped(_family_filter[_LinkedListFamily](predicate, rebind_var[LinkedList[T]](self.value^)))

    def filter[T: Movable & Deinitable, R: Movable & Deinitable, //, E: Movable & Deinitable, F: def(T) raises E -> R](
        deinit self, ref predicate: F
    ) raises E -> Piped[LinkedList[T]] where R == Bool and Self.Value == LinkedList[T]:
        """Retain accepted LinkedList payloads immediately, preserving their container."""
        comptime assert Self.Value == LinkedList[T]
        return Piped(_family_filter[_LinkedListFamily, E=E](predicate, rebind_var[LinkedList[T]](self.value^)))

    def filter[C: BorrowCallContract & Movable & Deinitable](
        deinit self, var predicate: C
    ) raises C.Failure -> Piped[LinkedList[downcast[C.Payload, Movable & Deinitable]]] where conforms_to(C.Payload, Movable & Deinitable) and Self.Value == LinkedList[downcast[C.Payload, Movable & Deinitable]] and C.Result == Bool and RepeatableBorrow[C]:
        """Retain accepted LinkedList payloads with an owned library predicate."""
        comptime assert Self.Value == LinkedList[downcast[C.Payload, Movable & Deinitable]]
        return Piped(_family_filter[_LinkedListFamily](predicate^, rebind_var[LinkedList[downcast[C.Payload, Movable & Deinitable]]](self.value^)))

    def filter[C: _BorrowViewable, o: ImmOrigin](
        deinit self, ref[o] predicate: C
    ) raises C._BorrowView[o].Failure -> Piped[LinkedList[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]] where conforms_to(C._BorrowView[o].Payload, Movable & Deinitable) and Self.Value == LinkedList[downcast[C._BorrowView[o].Payload, Movable & Deinitable]] and C._BorrowView[o].Result == Bool:
        """Retain accepted LinkedList payloads with a shared library predicate."""
        comptime assert Self.Value == LinkedList[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]
        return Piped(_family_filter[_LinkedListFamily](predicate._borrow_view(), rebind_var[LinkedList[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]](self.value^)))

    def filter[T: Movable & Deinitable, R: Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //, F: def(T) -> R](
        deinit self, ref predicate: F
    ) -> Piped[Dict[K, T, H]] where R == Bool and Self.Value == Dict[K, T, H]:
        """Retain accepted Dict payloads immediately, preserving their container."""
        comptime assert Self.Value == Dict[K, T, H]
        return Piped(_family_filter[_DictFamily[K, T, H]](predicate, rebind_var[Dict[K, T, H]](self.value^)))

    def filter[T: Movable & Deinitable, R: Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //, E: Movable & Deinitable, F: def(T) raises E -> R](
        deinit self, ref predicate: F
    ) raises E -> Piped[Dict[K, T, H]] where R == Bool and Self.Value == Dict[K, T, H]:
        """Retain accepted Dict payloads immediately, preserving their container."""
        comptime assert Self.Value == Dict[K, T, H]
        return Piped(_family_filter[_DictFamily[K, T, H], E=E](predicate, rebind_var[Dict[K, T, H]](self.value^)))

    def filter[C: BorrowCallContract & Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable](
        deinit self, var predicate: C
    ) raises C.Failure -> Piped[Dict[K, downcast[C.Payload, Movable & Deinitable], H]] where conforms_to(C.Payload, Movable & Deinitable) and Self.Value == Dict[K, downcast[C.Payload, Movable & Deinitable], H] and C.Result == Bool and RepeatableBorrow[C]:
        """Retain accepted Dict payloads with an owned library predicate."""
        comptime assert Self.Value == Dict[K, downcast[C.Payload, Movable & Deinitable], H]
        return Piped(_family_filter[_DictFamily[K, downcast[C.Payload, Movable & Deinitable], H]](predicate^, rebind_var[Dict[K, downcast[C.Payload, Movable & Deinitable], H]](self.value^)))

    def filter[C: _BorrowViewable, o: ImmOrigin, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable](
        deinit self, ref[o] predicate: C
    ) raises C._BorrowView[o].Failure -> Piped[Dict[K, downcast[C._BorrowView[o].Payload, Movable & Deinitable], H]] where conforms_to(C._BorrowView[o].Payload, Movable & Deinitable) and Self.Value == Dict[K, downcast[C._BorrowView[o].Payload, Movable & Deinitable], H] and C._BorrowView[o].Result == Bool:
        """Retain accepted Dict payloads with a shared library predicate."""
        comptime assert Self.Value == Dict[K, downcast[C._BorrowView[o].Payload, Movable & Deinitable], H]
        return Piped(_family_filter[_DictFamily[K, downcast[C._BorrowView[o].Payload, Movable & Deinitable], H]](predicate._borrow_view(), rebind_var[Dict[K, downcast[C._BorrowView[o].Payload, Movable & Deinitable], H]](self.value^)))

    def filter[T: Movable & Deinitable, R: Movable & Deinitable, //, F: def(T) -> R](
        deinit self, ref predicate: F
    ) -> Piped[StringDict[T]] where R == Bool and Self.Value == StringDict[T]:
        """Retain accepted StringDict payloads immediately, preserving their container."""
        comptime assert Self.Value == StringDict[T]
        return Piped(_family_filter[_StringDictFamily[T]](predicate, rebind_var[StringDict[T]](self.value^)))

    def filter[T: Movable & Deinitable, R: Movable & Deinitable, //, E: Movable & Deinitable, F: def(T) raises E -> R](
        deinit self, ref predicate: F
    ) raises E -> Piped[StringDict[T]] where R == Bool and Self.Value == StringDict[T]:
        """Retain accepted StringDict payloads immediately, preserving their container."""
        comptime assert Self.Value == StringDict[T]
        return Piped(_family_filter[_StringDictFamily[T], E=E](predicate, rebind_var[StringDict[T]](self.value^)))

    def filter[C: BorrowCallContract & Movable & Deinitable](
        deinit self, var predicate: C
    ) raises C.Failure -> Piped[StringDict[downcast[C.Payload, Movable & Deinitable]]] where conforms_to(C.Payload, Movable & Deinitable) and Self.Value == StringDict[downcast[C.Payload, Movable & Deinitable]] and C.Result == Bool and RepeatableBorrow[C]:
        """Retain accepted StringDict payloads with an owned library predicate."""
        comptime assert Self.Value == StringDict[downcast[C.Payload, Movable & Deinitable]]
        return Piped(_family_filter[_StringDictFamily[downcast[C.Payload, Movable & Deinitable]]](predicate^, rebind_var[StringDict[downcast[C.Payload, Movable & Deinitable]]](self.value^)))

    def filter[C: _BorrowViewable, o: ImmOrigin](
        deinit self, ref[o] predicate: C
    ) raises C._BorrowView[o].Failure -> Piped[StringDict[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]] where conforms_to(C._BorrowView[o].Payload, Movable & Deinitable) and Self.Value == StringDict[downcast[C._BorrowView[o].Payload, Movable & Deinitable]] and C._BorrowView[o].Result == Bool:
        """Retain accepted StringDict payloads with a shared library predicate."""
        comptime assert Self.Value == StringDict[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]
        return Piped(_family_filter[_StringDictFamily[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]](predicate._borrow_view(), rebind_var[StringDict[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]](self.value^)))

    def filter[T: Movable & Deinitable, R: Movable & Deinitable, //, F: def(T) -> R](
        deinit self, ref predicate: F
    ) -> Piped[Optional[T]] where R == Bool and Self.Value == Optional[T]:
        """Retain accepted Optional payloads immediately, preserving their container."""
        comptime assert Self.Value == Optional[T]
        return Piped(_family_filter[OptionalFamily](predicate, rebind_var[Optional[T]](self.value^)))

    def filter[T: Movable & Deinitable, R: Movable & Deinitable, //, E: Movable & Deinitable, F: def(T) raises E -> R](
        deinit self, ref predicate: F
    ) raises E -> Piped[Optional[T]] where R == Bool and Self.Value == Optional[T]:
        """Retain accepted Optional payloads immediately, preserving their container."""
        comptime assert Self.Value == Optional[T]
        return Piped(_family_filter[OptionalFamily, E=E](predicate, rebind_var[Optional[T]](self.value^)))

    def filter[C: BorrowCallContract & Movable & Deinitable](
        deinit self, var predicate: C
    ) raises C.Failure -> Piped[Optional[downcast[C.Payload, Movable & Deinitable]]] where conforms_to(C.Payload, Movable & Deinitable) and Self.Value == Optional[downcast[C.Payload, Movable & Deinitable]] and C.Result == Bool and RepeatableBorrow[C]:
        """Retain accepted Optional payloads with an owned library predicate."""
        comptime assert Self.Value == Optional[downcast[C.Payload, Movable & Deinitable]]
        return Piped(_family_filter[OptionalFamily](predicate^, rebind_var[Optional[downcast[C.Payload, Movable & Deinitable]]](self.value^)))

    def filter[C: _BorrowViewable, o: ImmOrigin](
        deinit self, ref[o] predicate: C
    ) raises C._BorrowView[o].Failure -> Piped[Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]] where conforms_to(C._BorrowView[o].Payload, Movable & Deinitable) and Self.Value == Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]] and C._BorrowView[o].Result == Bool:
        """Retain accepted Optional payloads with a shared library predicate."""
        comptime assert Self.Value == Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]
        return Piped(_family_filter[OptionalFamily](predicate._borrow_view(), rebind_var[Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]](self.value^)))

    def filter_not[T: Movable & Deinitable, R: Movable & Deinitable, //, F: def(T) -> R](
        deinit self, ref predicate: F
    ) -> Piped[List[T]] where R == Bool and Self.Value == List[T]:
        """Retain rejected List payloads immediately, preserving their container."""
        comptime assert Self.Value == List[T]
        return Piped(_family_filter_not[ListFamily](predicate, rebind_var[List[T]](self.value^)))

    def filter_not[T: Movable & Deinitable, R: Movable & Deinitable, //, E: Movable & Deinitable, F: def(T) raises E -> R](
        deinit self, ref predicate: F
    ) raises E -> Piped[List[T]] where R == Bool and Self.Value == List[T]:
        """Retain rejected List payloads immediately, preserving their container."""
        comptime assert Self.Value == List[T]
        return Piped(_family_filter_not[ListFamily, E=E](predicate, rebind_var[List[T]](self.value^)))

    def filter_not[C: BorrowCallContract & Movable & Deinitable](
        deinit self, var predicate: C
    ) raises C.Failure -> Piped[List[downcast[C.Payload, Movable & Deinitable]]] where conforms_to(C.Payload, Movable & Deinitable) and Self.Value == List[downcast[C.Payload, Movable & Deinitable]] and C.Result == Bool and RepeatableBorrow[C]:
        """Retain rejected List payloads with an owned library predicate."""
        comptime assert Self.Value == List[downcast[C.Payload, Movable & Deinitable]]
        return Piped(_family_filter_not[ListFamily](predicate^, rebind_var[List[downcast[C.Payload, Movable & Deinitable]]](self.value^)))

    def filter_not[C: _BorrowViewable, o: ImmOrigin](
        deinit self, ref[o] predicate: C
    ) raises C._BorrowView[o].Failure -> Piped[List[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]] where conforms_to(C._BorrowView[o].Payload, Movable & Deinitable) and Self.Value == List[downcast[C._BorrowView[o].Payload, Movable & Deinitable]] and C._BorrowView[o].Result == Bool:
        """Retain rejected List payloads with a shared library predicate."""
        comptime assert Self.Value == List[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]
        return Piped(_family_filter_not[ListFamily](predicate._borrow_view(), rebind_var[List[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]](self.value^)))

    def filter_not[T: Movable & Deinitable, R: Movable & Deinitable, //, F: def(T) -> R](
        deinit self, ref predicate: F
    ) -> Piped[Deque[T]] where R == Bool and Self.Value == Deque[T]:
        """Retain rejected Deque payloads immediately, preserving their container."""
        comptime assert Self.Value == Deque[T]
        return Piped(_family_filter_not[_DequeFamily](predicate, rebind_var[Deque[T]](self.value^)))

    def filter_not[T: Movable & Deinitable, R: Movable & Deinitable, //, E: Movable & Deinitable, F: def(T) raises E -> R](
        deinit self, ref predicate: F
    ) raises E -> Piped[Deque[T]] where R == Bool and Self.Value == Deque[T]:
        """Retain rejected Deque payloads immediately, preserving their container."""
        comptime assert Self.Value == Deque[T]
        return Piped(_family_filter_not[_DequeFamily, E=E](predicate, rebind_var[Deque[T]](self.value^)))

    def filter_not[C: BorrowCallContract & Movable & Deinitable](
        deinit self, var predicate: C
    ) raises C.Failure -> Piped[Deque[downcast[C.Payload, Movable & Deinitable]]] where conforms_to(C.Payload, Movable & Deinitable) and Self.Value == Deque[downcast[C.Payload, Movable & Deinitable]] and C.Result == Bool and RepeatableBorrow[C]:
        """Retain rejected Deque payloads with an owned library predicate."""
        comptime assert Self.Value == Deque[downcast[C.Payload, Movable & Deinitable]]
        return Piped(_family_filter_not[_DequeFamily](predicate^, rebind_var[Deque[downcast[C.Payload, Movable & Deinitable]]](self.value^)))

    def filter_not[C: _BorrowViewable, o: ImmOrigin](
        deinit self, ref[o] predicate: C
    ) raises C._BorrowView[o].Failure -> Piped[Deque[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]] where conforms_to(C._BorrowView[o].Payload, Movable & Deinitable) and Self.Value == Deque[downcast[C._BorrowView[o].Payload, Movable & Deinitable]] and C._BorrowView[o].Result == Bool:
        """Retain rejected Deque payloads with a shared library predicate."""
        comptime assert Self.Value == Deque[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]
        return Piped(_family_filter_not[_DequeFamily](predicate._borrow_view(), rebind_var[Deque[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]](self.value^)))

    def filter_not[T: Movable & Deinitable, R: Movable & Deinitable, //, F: def(T) -> R](
        deinit self, ref predicate: F
    ) -> Piped[LinkedList[T]] where R == Bool and Self.Value == LinkedList[T]:
        """Retain rejected LinkedList payloads immediately, preserving their container."""
        comptime assert Self.Value == LinkedList[T]
        return Piped(_family_filter_not[_LinkedListFamily](predicate, rebind_var[LinkedList[T]](self.value^)))

    def filter_not[T: Movable & Deinitable, R: Movable & Deinitable, //, E: Movable & Deinitable, F: def(T) raises E -> R](
        deinit self, ref predicate: F
    ) raises E -> Piped[LinkedList[T]] where R == Bool and Self.Value == LinkedList[T]:
        """Retain rejected LinkedList payloads immediately, preserving their container."""
        comptime assert Self.Value == LinkedList[T]
        return Piped(_family_filter_not[_LinkedListFamily, E=E](predicate, rebind_var[LinkedList[T]](self.value^)))

    def filter_not[C: BorrowCallContract & Movable & Deinitable](
        deinit self, var predicate: C
    ) raises C.Failure -> Piped[LinkedList[downcast[C.Payload, Movable & Deinitable]]] where conforms_to(C.Payload, Movable & Deinitable) and Self.Value == LinkedList[downcast[C.Payload, Movable & Deinitable]] and C.Result == Bool and RepeatableBorrow[C]:
        """Retain rejected LinkedList payloads with an owned library predicate."""
        comptime assert Self.Value == LinkedList[downcast[C.Payload, Movable & Deinitable]]
        return Piped(_family_filter_not[_LinkedListFamily](predicate^, rebind_var[LinkedList[downcast[C.Payload, Movable & Deinitable]]](self.value^)))

    def filter_not[C: _BorrowViewable, o: ImmOrigin](
        deinit self, ref[o] predicate: C
    ) raises C._BorrowView[o].Failure -> Piped[LinkedList[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]] where conforms_to(C._BorrowView[o].Payload, Movable & Deinitable) and Self.Value == LinkedList[downcast[C._BorrowView[o].Payload, Movable & Deinitable]] and C._BorrowView[o].Result == Bool:
        """Retain rejected LinkedList payloads with a shared library predicate."""
        comptime assert Self.Value == LinkedList[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]
        return Piped(_family_filter_not[_LinkedListFamily](predicate._borrow_view(), rebind_var[LinkedList[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]](self.value^)))

    def filter_not[T: Movable & Deinitable, R: Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //, F: def(T) -> R](
        deinit self, ref predicate: F
    ) -> Piped[Dict[K, T, H]] where R == Bool and Self.Value == Dict[K, T, H]:
        """Retain rejected Dict payloads immediately, preserving their container."""
        comptime assert Self.Value == Dict[K, T, H]
        return Piped(_family_filter_not[_DictFamily[K, T, H]](predicate, rebind_var[Dict[K, T, H]](self.value^)))

    def filter_not[T: Movable & Deinitable, R: Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //, E: Movable & Deinitable, F: def(T) raises E -> R](
        deinit self, ref predicate: F
    ) raises E -> Piped[Dict[K, T, H]] where R == Bool and Self.Value == Dict[K, T, H]:
        """Retain rejected Dict payloads immediately, preserving their container."""
        comptime assert Self.Value == Dict[K, T, H]
        return Piped(_family_filter_not[_DictFamily[K, T, H], E=E](predicate, rebind_var[Dict[K, T, H]](self.value^)))

    def filter_not[C: BorrowCallContract & Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable](
        deinit self, var predicate: C
    ) raises C.Failure -> Piped[Dict[K, downcast[C.Payload, Movable & Deinitable], H]] where conforms_to(C.Payload, Movable & Deinitable) and Self.Value == Dict[K, downcast[C.Payload, Movable & Deinitable], H] and C.Result == Bool and RepeatableBorrow[C]:
        """Retain rejected Dict payloads with an owned library predicate."""
        comptime assert Self.Value == Dict[K, downcast[C.Payload, Movable & Deinitable], H]
        return Piped(_family_filter_not[_DictFamily[K, downcast[C.Payload, Movable & Deinitable], H]](predicate^, rebind_var[Dict[K, downcast[C.Payload, Movable & Deinitable], H]](self.value^)))

    def filter_not[C: _BorrowViewable, o: ImmOrigin, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable](
        deinit self, ref[o] predicate: C
    ) raises C._BorrowView[o].Failure -> Piped[Dict[K, downcast[C._BorrowView[o].Payload, Movable & Deinitable], H]] where conforms_to(C._BorrowView[o].Payload, Movable & Deinitable) and Self.Value == Dict[K, downcast[C._BorrowView[o].Payload, Movable & Deinitable], H] and C._BorrowView[o].Result == Bool:
        """Retain rejected Dict payloads with a shared library predicate."""
        comptime assert Self.Value == Dict[K, downcast[C._BorrowView[o].Payload, Movable & Deinitable], H]
        return Piped(_family_filter_not[_DictFamily[K, downcast[C._BorrowView[o].Payload, Movable & Deinitable], H]](predicate._borrow_view(), rebind_var[Dict[K, downcast[C._BorrowView[o].Payload, Movable & Deinitable], H]](self.value^)))

    def filter_not[T: Movable & Deinitable, R: Movable & Deinitable, //, F: def(T) -> R](
        deinit self, ref predicate: F
    ) -> Piped[StringDict[T]] where R == Bool and Self.Value == StringDict[T]:
        """Retain rejected StringDict payloads immediately, preserving their container."""
        comptime assert Self.Value == StringDict[T]
        return Piped(_family_filter_not[_StringDictFamily[T]](predicate, rebind_var[StringDict[T]](self.value^)))

    def filter_not[T: Movable & Deinitable, R: Movable & Deinitable, //, E: Movable & Deinitable, F: def(T) raises E -> R](
        deinit self, ref predicate: F
    ) raises E -> Piped[StringDict[T]] where R == Bool and Self.Value == StringDict[T]:
        """Retain rejected StringDict payloads immediately, preserving their container."""
        comptime assert Self.Value == StringDict[T]
        return Piped(_family_filter_not[_StringDictFamily[T], E=E](predicate, rebind_var[StringDict[T]](self.value^)))

    def filter_not[C: BorrowCallContract & Movable & Deinitable](
        deinit self, var predicate: C
    ) raises C.Failure -> Piped[StringDict[downcast[C.Payload, Movable & Deinitable]]] where conforms_to(C.Payload, Movable & Deinitable) and Self.Value == StringDict[downcast[C.Payload, Movable & Deinitable]] and C.Result == Bool and RepeatableBorrow[C]:
        """Retain rejected StringDict payloads with an owned library predicate."""
        comptime assert Self.Value == StringDict[downcast[C.Payload, Movable & Deinitable]]
        return Piped(_family_filter_not[_StringDictFamily[downcast[C.Payload, Movable & Deinitable]]](predicate^, rebind_var[StringDict[downcast[C.Payload, Movable & Deinitable]]](self.value^)))

    def filter_not[C: _BorrowViewable, o: ImmOrigin](
        deinit self, ref[o] predicate: C
    ) raises C._BorrowView[o].Failure -> Piped[StringDict[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]] where conforms_to(C._BorrowView[o].Payload, Movable & Deinitable) and Self.Value == StringDict[downcast[C._BorrowView[o].Payload, Movable & Deinitable]] and C._BorrowView[o].Result == Bool:
        """Retain rejected StringDict payloads with a shared library predicate."""
        comptime assert Self.Value == StringDict[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]
        return Piped(_family_filter_not[_StringDictFamily[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]](predicate._borrow_view(), rebind_var[StringDict[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]](self.value^)))

    def filter_not[T: Movable & Deinitable, R: Movable & Deinitable, //, F: def(T) -> R](
        deinit self, ref predicate: F
    ) -> Piped[Optional[T]] where R == Bool and Self.Value == Optional[T]:
        """Retain rejected Optional payloads immediately, preserving their container."""
        comptime assert Self.Value == Optional[T]
        return Piped(_family_filter_not[OptionalFamily](predicate, rebind_var[Optional[T]](self.value^)))

    def filter_not[T: Movable & Deinitable, R: Movable & Deinitable, //, E: Movable & Deinitable, F: def(T) raises E -> R](
        deinit self, ref predicate: F
    ) raises E -> Piped[Optional[T]] where R == Bool and Self.Value == Optional[T]:
        """Retain rejected Optional payloads immediately, preserving their container."""
        comptime assert Self.Value == Optional[T]
        return Piped(_family_filter_not[OptionalFamily, E=E](predicate, rebind_var[Optional[T]](self.value^)))

    def filter_not[C: BorrowCallContract & Movable & Deinitable](
        deinit self, var predicate: C
    ) raises C.Failure -> Piped[Optional[downcast[C.Payload, Movable & Deinitable]]] where conforms_to(C.Payload, Movable & Deinitable) and Self.Value == Optional[downcast[C.Payload, Movable & Deinitable]] and C.Result == Bool and RepeatableBorrow[C]:
        """Retain rejected Optional payloads with an owned library predicate."""
        comptime assert Self.Value == Optional[downcast[C.Payload, Movable & Deinitable]]
        return Piped(_family_filter_not[OptionalFamily](predicate^, rebind_var[Optional[downcast[C.Payload, Movable & Deinitable]]](self.value^)))

    def filter_not[C: _BorrowViewable, o: ImmOrigin](
        deinit self, ref[o] predicate: C
    ) raises C._BorrowView[o].Failure -> Piped[Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]] where conforms_to(C._BorrowView[o].Payload, Movable & Deinitable) and Self.Value == Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]] and C._BorrowView[o].Result == Bool:
        """Retain rejected Optional payloads with a shared library predicate."""
        comptime assert Self.Value == Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]
        return Piped(_family_filter_not[OptionalFamily](predicate._borrow_view(), rebind_var[Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]](self.value^)))

    def fill[T: Movable & Deinitable, U: Movable & Deinitable, //, I: Functor](deinit self, var value: U) raises I.MapError[Self.Value, _Fill[T, U]] -> Piped[I.Mapped[Self.Value, _Fill[T, U]]] where I.Element[Self.Value] == T and _MapCompatible[I, Self.Value, _Fill[T, U]]:
        """Replace payloads with value, moving it for a single call or copying for repeated calls.

        Parameters:
            T: The element type, including its native origins.
            U: The constant or result payload type; repeated constants must be Copyable.
            I: The explicit capability family, including its result and error semantics.

        Args:
            value: The constant, consumed and copied once per emitted payload.

        Returns:
            The source shape with a copy of value at each payload position; empty input stays empty.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(I.map(_Fill[T, U](value^), self.value^))

    def replace[T: Copyable & Equatable & Deinitable, //, I: Functor](deinit self, var old: T, var new: T) raises I.MapError[Self.Value, _Replace[T]] -> Piped[I.Mapped[Self.Value, _Replace[T]]] where I.Element[Self.Value] == T and _MapCompatible[I, Self.Value, _Replace[T]]:
        """Replace equal payloads, moving unmatched values unchanged.

        Parameters:
            T: The element type, including its native origins.
            I: The explicit capability family, including its result and error semantics.

        Args:
            old: The value to compare against each payload, consumed.
            new: The replacement, consumed and copied only for matching payloads.

        Returns:
            The source shape with matching elements replaced and unmatched elements moved unchanged.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(I.map(_Replace[T](old^, new^), self.value^))

    def void[T: Movable & Deinitable, //, I: Functor](deinit self) raises I.MapError[Self.Value, _Fill[T, NoneType]] -> Piped[I.Mapped[Self.Value, _Fill[T, NoneType]]] where I.Element[Self.Value] == T and _MapCompatible[I, Self.Value, _Fill[T, NoneType]]:
        """Discard payloads while preserving their container shape.

        Parameters:
            T: The element type, including its native origins.
            I: The explicit capability family, including its result and error semantics.

        Returns:
            The source shape with NoneType payloads; a lazy iterator is not drained.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(I.map(_Fill[T, NoneType](None), self.value^))

    def tuple_left[T: Movable & Deinitable, U: Movable & Deinitable, //, I: Functor](deinit self, var value: U) raises I.MapError[Self.Value, _TupleWith[T, U, True]] -> Piped[I.Mapped[Self.Value, _TupleWith[T, U, True]]] where I.Element[Self.Value] == T and _MapCompatible[I, Self.Value, _TupleWith[T, U, True]]:
        """Attach value on the left, moving it for a single call or copying for repeated calls.

        Parameters:
            T: The element type, including its native origins.
            U: The constant or result payload type; repeated constants must be Copyable.
            I: The explicit capability family, including its result and error semantics.

        Args:
            value: The constant, consumed and copied once per emitted payload.

        Returns:
            The source shape containing a copied constant followed by each original element.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(I.map(_TupleWith[T, U, True](value^), self.value^))

    def tuple_right[T: Movable & Deinitable, U: Movable & Deinitable, //, I: Functor](deinit self, var value: U) raises I.MapError[Self.Value, _TupleWith[T, U, False]] -> Piped[I.Mapped[Self.Value, _TupleWith[T, U, False]]] where I.Element[Self.Value] == T and _MapCompatible[I, Self.Value, _TupleWith[T, U, False]]:
        """Attach value on the right, moving it for a single call or copying for repeated calls.

        Parameters:
            T: The element type, including its native origins.
            U: The constant or result payload type; repeated constants must be Copyable.
            I: The explicit capability family, including its result and error semantics.

        Args:
            value: The constant, consumed and copied once per emitted payload.

        Returns:
            The source shape containing each original element followed by a copied constant.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(I.map(_TupleWith[T, U, False](value^), self.value^))

    def pair_with[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, I: Functor, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises I.MapError[Self.Value, _Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], True]] -> Piped[I.Mapped[Self.Value, _Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], True]]] where I.Element[Self.Value] == downcast[P, Movable & Deinitable] and _MapCompatible[I, Self.Value, _Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], True]]:
        """Borrow each payload for projection and retain it beside the result.

        Parameters:
            P: The borrowed callback payload type, including its native origins.
            R: The native callback result type.
            o: The origin of the borrowed native callback.
            I: The explicit capability family, including its result and error semantics.
            F: The callback type, retaining its receiver, captures and error contract.

        Args:
            function: The callback, borrowed in place; calls follow the operation's evaluation order.

        Returns:
            The source shape containing each original element beside its borrowed projection.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(I.map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), self.value^))

    def pair_with[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, I: Functor, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises I.MapError[Self.Value, _Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], True]] -> Piped[I.Mapped[Self.Value, _Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], True]]] where I.Element[Self.Value] == downcast[P, Movable & Deinitable] and _MapCompatible[I, Self.Value, _Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], True]]:
        """Borrow each payload for projection and retain it beside the result."""
        return Piped(I.map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), self.value^))

    def pair_with[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, //, I: Functor](deinit self, var function: C) raises I.MapError[Self.Value, _Observe[T, C, True]] -> Piped[I.Mapped[Self.Value, _Observe[T, C, True]]] where I.Element[Self.Value] == T and _MapCompatible[I, Self.Value, _Observe[T, C, True]] and C.Payload == T and RepeatableBorrow[C]:
        """Borrow each payload for projection and retain it beside the result."""
        return Piped(I.map(_Observe[T, C, True](function^), self.value^))

    def tap_each[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, I: Functor, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises I.MapError[Self.Value, _Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], False]] -> Piped[I.Mapped[Self.Value, _Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], False]]] where I.Element[Self.Value] == downcast[P, Movable & Deinitable] and _MapCompatible[I, Self.Value, _Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], False]]:
        """Borrow each payload for inspection and retain it unchanged.

        Parameters:
            P: The borrowed callback payload type, including its native origins.
            R: The native callback result type.
            o: The origin of the borrowed native callback.
            I: The explicit capability family, including its result and error semantics.
            F: The callback type, retaining its receiver, captures and error contract.

        Args:
            function: The callback, borrowed in place; calls follow the operation's evaluation order.

        Returns:
            The original elements after inspection; callback results are discarded.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(I.map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], False](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), self.value^))

    def tap_each[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, I: Functor, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises I.MapError[Self.Value, _Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], False]] -> Piped[I.Mapped[Self.Value, _Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], False]]] where I.Element[Self.Value] == downcast[P, Movable & Deinitable] and _MapCompatible[I, Self.Value, _Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], False]]:
        """Borrow each payload for inspection and retain it unchanged."""
        return Piped(I.map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], False](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), self.value^))

    def tap_each[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, //, I: Functor](deinit self, var function: C) raises I.MapError[Self.Value, _Observe[T, C, False]] -> Piped[I.Mapped[Self.Value, _Observe[T, C, False]]] where I.Element[Self.Value] == T and _MapCompatible[I, Self.Value, _Observe[T, C, False]] and C.Payload == T and RepeatableBorrow[C]:
        """Borrow each payload for inspection and retain it unchanged."""
        return Piped(I.map(_Observe[T, C, False](function^), self.value^))

    def filter_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, I: FunctorFilter, F: _Unary[A, R]](deinit self, ref[o] function: F) raises I.MapFilterError[Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]] -> Piped[I.MapFiltered[Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]]] where I.Element[Self.Value] == A:
        """Apply filter_map through the carrier's FunctorFilter capability.

        Parameters:
            A: The callback input type, including its native origins.
            R: The native callback result type.
            o: The origin of the borrowed native callback.
            I: The explicit capability family, including its result and error semantics.
            F: The callback type, retaining its receiver, captures and error contract.

        Args:
            function: The callback, borrowed in place; calls follow the operation's evaluation order.

        Returns:
            The carrier of present transformed Optional payloads, in source order.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(I.filter_map(_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), self.value^))

    def filter_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, I: FunctorFilter, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises I.MapFilterError[Self.Value, _NativeUnaryRef[A, R, E, F, True, o]] -> Piped[I.MapFiltered[Self.Value, _NativeUnaryRef[A, R, E, F, True, o]]] where I.Element[Self.Value] == A:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        return Piped(I.filter_map(_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self.value^))

    def filter_map[F: UnaryContract & Movable & Deinitable, //, I: FunctorFilter](deinit self, var function: F) raises I.MapFilterError[Self.Value, F] -> Piped[I.MapFiltered[Self.Value, F]] where I.Element[Self.Value] == F.Arg:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        return Piped(I.filter_map(function^, self.value^))

    def filter_map[F: _UnaryViewable, o: ImmOrigin, //, I: FunctorFilter](deinit self, ref[o] function: F) raises I.MapFilterError[Self.Value, F._View[o]] -> Piped[I.MapFiltered[Self.Value, F._View[o]]] where I.Element[Self.Value] == F._View[o].Arg:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        return Piped(I.filter_map(function._unary_view(), self.value^))

    def flat_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, I: Monad, F: _Unary[A, R]](deinit self, ref[o] function: F) raises I.BindError[Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]] -> Piped[I.Bound[Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]]] where I.Element[Self.Value] == A and _BindCompatible[I, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]]:
        """Apply flat_map through the carrier's Monad capability.

        Parameters:
            A: The callback input type, including its native origins.
            R: The native callback result type.
            o: The origin of the borrowed native callback.
            I: The explicit capability family, including its result and error semantics.
            F: The callback type, retaining its receiver, captures and error contract.

        Args:
            function: The callback, borrowed in place; calls follow the operation's evaluation order.

        Returns:
            The family result of transforming and flattening one level.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(I.flat_map(_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), self.value^))

    def flat_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, I: Monad, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises I.BindError[Self.Value, _NativeUnaryRef[A, R, E, F, True, o]] -> Piped[I.Bound[Self.Value, _NativeUnaryRef[A, R, E, F, True, o]]] where I.Element[Self.Value] == A and _BindCompatible[I, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]]:
        """Apply flat_map through the carrier's Monad capability."""
        return Piped(I.flat_map(_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self.value^))

    def flat_map[F: UnaryContract & Movable & Deinitable, //, I: Monad](deinit self, var function: F) raises I.BindError[Self.Value, F] -> Piped[I.Bound[Self.Value, F]] where I.Element[Self.Value] == F.Arg and _BindCompatible[I, Self.Value, F]:
        """Apply flat_map through the carrier's Monad capability."""
        return Piped(I.flat_map(function^, self.value^))

    def flat_map[F: _UnaryViewable, o: ImmOrigin, //, I: Monad](deinit self, ref[o] function: F) raises I.BindError[Self.Value, F._View[o]] -> Piped[I.Bound[Self.Value, F._View[o]]] where I.Element[Self.Value] == F._View[o].Arg and _BindCompatible[I, Self.Value, F._View[o]]:
        """Apply flat_map through the carrier's Monad capability."""
        return Piped(I.flat_map(function._unary_view(), self.value^))

    def traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, I: Traversable, G: Applicative, F: _Unary[A, R]](deinit self, ref[o] function: F) raises I.TraverseError[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]] -> Piped[I.Traversed[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]]] where I.Element[Self.Value] == A and I.TargetCompatible[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]]:
        """Apply traverse through the carrier's Traversable capability.

        Parameters:
            A: The callback input type, including its native origins.
            R: The native callback result type.
            o: The origin of the borrowed native callback.
            I: The explicit capability family, including its result and error semantics.
            G: The target Applicative family; it determines effect sequencing and failure.
            F: The callback type, retaining its receiver, captures and error contract.

        Args:
            function: The callback, borrowed in place; calls follow the operation's evaluation order.

        Returns:
            The target effect containing transformed payloads; Iter and direct calls gather a List.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(I.traverse[G](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), self.value^))

    def traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, I: Traversable, G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises I.TraverseError[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]] -> Piped[I.Traversed[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]]] where I.Element[Self.Value] == A and I.TargetCompatible[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]]:
        """Apply traverse through the carrier's Traversable capability."""
        return Piped(I.traverse[G](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self.value^))

    def traverse[F: UnaryContract & Movable & Deinitable, //, I: Traversable, G: Applicative](deinit self, var function: F) raises I.TraverseError[G, Self.Value, F] -> Piped[I.Traversed[G, Self.Value, F]] where I.Element[Self.Value] == F.Arg and I.TargetCompatible[G, Self.Value, F]:
        """Apply traverse through the carrier's Traversable capability."""
        return Piped(I.traverse[G](function^, self.value^))

    def traverse[F: _UnaryViewable, o: ImmOrigin, //, I: Traversable, G: Applicative](deinit self, ref[o] function: F) raises I.TraverseError[G, Self.Value, F._View[o]] -> Piped[I.Traversed[G, Self.Value, F._View[o]]] where I.Element[Self.Value] == F._View[o].Arg and I.TargetCompatible[G, Self.Value, F._View[o]]:
        """Apply traverse through the carrier's Traversable capability."""
        return Piped(I.traverse[G](function._unary_view(), self.value^))

    def compact[I: FunctorFilter](deinit self) raises I.MapFilterError[Self.Value, _Same[I.Element[Self.Value]]] -> Piped[I.MapFiltered[Self.Value, _Same[I.Element[Self.Value]]]]:
        """Derive compact through filter_map, preserving the family's semantics.

        Parameters:
            I: The explicit capability family, including its result and error semantics.

        Returns:
            The carrier of unwrapped present Optional payloads, in source order.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(I.filter_map(_Same[I.Element[Self.Value]](), self.value^))

    def flatten[I: Monad](deinit self) raises I.BindError[Self.Value, _Same[I.Element[Self.Value]]] -> Piped[I.Bound[Self.Value, _Same[I.Element[Self.Value]]]] where _BindCompatible[I, Self.Value, _Same[I.Element[Self.Value]]]:
        """Derive flatten through flat_map, preserving the family's semantics.

        Parameters:
            I: The explicit capability family, including its result and error semantics.

        Returns:
            The result of removing one nesting level according to the family.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(I.flat_map(_Same[I.Element[Self.Value]](), self.value^))

    def sequence[I: Traversable, G: Applicative](deinit self) raises I.TraverseError[G, Self.Value, _Same[I.Element[Self.Value]]] -> Piped[I.Traversed[G, Self.Value, _Same[I.Element[Self.Value]]]] where I.TargetCompatible[G, Self.Value, _Same[I.Element[Self.Value]]]:
        """Derive sequence through traverse, preserving the family's semantics.

        Parameters:
            I: The explicit capability family, including its result and error semantics.
            G: The target Applicative family; it determines effect sequencing and failure.

        Returns:
            The target effect containing unwrapped payloads; Iter and direct calls gather a List.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(I.traverse[G](_Same[I.Element[Self.Value]](), self.value^))

    def map2[F: BinaryContract & Movable & Deinitable, W: Movable & Deinitable, //, I: Applicative](deinit self, var other: W, var function: F) raises Map2Contract[I, Self.Value, W, F].Error -> Piped[Map2Contract[I, Self.Value, W, F].Out] where Map2Contract[I, Self.Value, W, F].InputCompatible and Map2Contract[I, Self.Value, W, F].OperationCompatible:
        """Combine two already evaluated carriers, following their Applicative semantics.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            W: The second carrier type, including its origins.
            I: The explicit capability family, including its result and error semantics.

        Args:
            other: The already evaluated second carrier, consumed. Constructing it is not deferred by this call.
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The combined carrier; Result keeps the first stored error, Optional requires both values, and List produces a Cartesian product in left-major order.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_map2_as[I, X=Map2Contract[I, Self.Value, W, F].Error](function^, self.value^, other^))

    def map2[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W: Movable & Deinitable, //, I: Applicative, F: _Binary[A, B, R]](deinit self, var other: W, ref[o] function: F) raises I.CombineError[Self.Value, _NativeBinaryRef[A, B, R, Never, F, False, o], _ValueThunk[W]] -> Piped[I.Combined[Self.Value, _NativeBinaryRef[A, B, R, Never, F, False, o], _ValueThunk[W]]] where I.Element[Self.Value] == A and I.Element[W] == B and _CombineCompatible[I, Self.Value, _NativeBinaryRef[A, B, R, Never, F, False, o], _ValueThunk[W]]:
        """Combine two already evaluated carriers, following their Applicative semantics."""
        return Piped(_map2_as[I, X=I.CombineError[Self.Value, _NativeBinaryRef[A, B, R, Never, F, False, o], _ValueThunk[W]]](_NativeBinaryRef[A, B, R, Never, F, False, o](Pointer(to=function)), self.value^, other^))

    def map2[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W: Movable & Deinitable, //, I: Applicative, X: Movable & Deinitable, F: _RaisingBinary[A, B, R, X]](deinit self, var other: W, ref[o] function: F) raises I.CombineError[Self.Value, _NativeBinaryRef[A, B, R, X, F, True, o], _ValueThunk[W]] -> Piped[I.Combined[Self.Value, _NativeBinaryRef[A, B, R, X, F, True, o], _ValueThunk[W]]] where I.Element[Self.Value] == A and I.Element[W] == B and _CombineCompatible[I, Self.Value, _NativeBinaryRef[A, B, R, X, F, True, o], _ValueThunk[W]]:
        """Combine two already evaluated carriers, following their Applicative semantics."""
        return Piped(_map2_as[I, X=I.CombineError[Self.Value, _NativeBinaryRef[A, B, R, X, F, True, o], _ValueThunk[W]]](_NativeBinaryRef[A, B, R, X, F, True, o](Pointer(to=function)), self.value^, other^))

    def product[W: Movable & Deinitable, //, I: Applicative](deinit self, var other: W) raises ProductContract[I, Self.Value, W].Error -> Piped[ProductContract[I, Self.Value, W].Out] where ProductContract[I, Self.Value, W].OperationCompatible:
        """Combine two already evaluated carriers into pairs, following their Applicative semantics.

        Parameters:
            W: The second carrier type, including its origins.
            I: The explicit capability family, including its result and error semantics.

        Args:
            other: The already evaluated second carrier, consumed. Constructing it is not deferred by this call.

        Returns:
            The carrier of pairs. List copies elements for its Cartesian product; Result and Optional move their payloads without copying.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_family_product[I](self.value^, other^))

    def ap[W: Movable & Deinitable, //, I: Applicative](deinit self, var values: W) raises ApContract[I, Self.Value, W].Error -> Piped[ApContract[I, Self.Value, W].Out] where ApContract[I, Self.Value, W].InputCompatible:
        """Apply the callbacks in this carrier to an already evaluated carrier of arguments.

        Parameters:
            W: The second carrier type, including its origins.
            I: The explicit capability family, including its result and error semantics.

        Args:
            values: The already evaluated carrier of callback arguments, consumed.

        Returns:
            The carrier of callback results. List applies each callback to each value in function-major order; Optional and Result invoke at most once.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_map2_as[I, X=ApContract[I, Self.Value, W].Error](_Apply[ApContract[I, Self.Value, W].Function](), self.value^, values^))

    def product_n[I: Applicative, *Ws: Movable & Deinitable](deinit self, var others: Tuple[*Ws]) raises _ProductTypes[I, Self.Value, *Ws].Error -> Piped[_ProductTypes[I, Self.Value, *Ws].Out] where Ws.length < 8:
        """Combine the receiver and additional operands into flat tuples.

        Parameters:
            I: The explicit Applicative family; at most eight operands in total.
            Ws: The exact additional carrier types, including origins.

        Args:
            others: The tuple of already evaluated additional operands, consumed.

        Returns:
            The family of flat tuples in receiver-first order. No additional
            operands produces one-element tuples. List uses Cartesian ordering.

        Raises:
            The exact family construction error; stored Result errors remain data.
        """
        return Piped(_ProductRun[I, Self.Value, *Ws].run[_ProductTypes[I, Self.Value, *Ws].Out, _ProductTypes[I, Self.Value, *Ws].Error](self.value^, others^))

    def map_n[F: UnaryContract & Movable & Deinitable, //, I: Applicative, *Ws: Movable & Deinitable](deinit self, var others: Tuple[*Ws], var function: F) raises _MapNTypes[I, Self.Value, F, *Ws].Error -> Piped[_MapNTypes[I, Self.Value, F, *Ws].Out] where Ws.length < 8 and F.Arg == _ProductRun[I, Self.Value, *Ws].Payload:
        """Combine operands, then map a callback over each flat tuple of payloads.

        Native callbacks take one argument per operand, from one to eight.
        Library Unary callbacks consume the whole tuple in their receiver mode.

        Parameters:
            F: The tuple callback, retaining its exact argument, result and error.
            I: The explicit Applicative family; at most eight operands in total.
            Ws: The exact additional carrier types, including origins.

        Args:
            others: The already evaluated additional operands, consumed.
            function: The callback, consumed; native callbacks are borrowed.

        Returns:
            The family of callback results; absence or failure skips the callback.
            List materializes the Cartesian tuples before mapping them in order.

        Raises:
            The exact callback or family construction error, without conversion.
        """
        return Piped(_map_n_as[I, _ProductTypes[I, Self.Value, *Ws].Out, _MapNTypes[I, Self.Value, F, *Ws].Out, _MapNTypes[I, Self.Value, F, *Ws].Error](function^, self.value^, others^))

    def map_n[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, I: Applicative, F: _Unary[A, R]](deinit self, var others: Tuple[], ref[o] function: F) raises _MapNTypes[I, Self.Value, _NativeNary1[A, R, Never, F, False, o]].Error -> Piped[_MapNTypes[I, Self.Value, _NativeNary1[A, R, Never, F, False, o]].Out] where I.Element[Self.Value] == A:
        """Combine 1 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[I, _ProductTypes[I, Self.Value].Out, _MapNTypes[I, Self.Value, _NativeNary1[A, R, Never, F, False, o]].Out, _MapNTypes[I, Self.Value, _NativeNary1[A, R, Never, F, False, o]].Error](_NativeNary1[A, R, Never, F, False, o](Pointer(to=function)), self.value^, others^))

    def map_n[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, I: Applicative, X: Movable & Deinitable, F: _RaisingUnary[A, R, X]](deinit self, var others: Tuple[], ref[o] function: F) raises _MapNTypes[I, Self.Value, _NativeNary1[A, R, X, F, True, o]].Error -> Piped[_MapNTypes[I, Self.Value, _NativeNary1[A, R, X, F, True, o]].Out] where I.Element[Self.Value] == A:
        """Combine 1 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[I, _ProductTypes[I, Self.Value].Out, _MapNTypes[I, Self.Value, _NativeNary1[A, R, X, F, True, o]].Out, _MapNTypes[I, Self.Value, _NativeNary1[A, R, X, F, True, o]].Error](_NativeNary1[A, R, X, F, True, o](Pointer(to=function)), self.value^, others^))

    def map_n[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, //, I: Applicative, F: _Binary[A, B, R]](deinit self, var others: Tuple[W0], ref[o] function: F) raises _MapNTypes[I, Self.Value, _NativeNary2[A, B, R, Never, F, False, o], W0].Error -> Piped[_MapNTypes[I, Self.Value, _NativeNary2[A, B, R, Never, F, False, o], W0].Out] where I.Element[Self.Value] == A and I.Element[W0] == B:
        """Combine 2 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[I, _ProductTypes[I, Self.Value, W0].Out, _MapNTypes[I, Self.Value, _NativeNary2[A, B, R, Never, F, False, o], W0].Out, _MapNTypes[I, Self.Value, _NativeNary2[A, B, R, Never, F, False, o], W0].Error](_NativeNary2[A, B, R, Never, F, False, o](Pointer(to=function)), self.value^, others^))

    def map_n[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, //, I: Applicative, X: Movable & Deinitable, F: _RaisingBinary[A, B, R, X]](deinit self, var others: Tuple[W0], ref[o] function: F) raises _MapNTypes[I, Self.Value, _NativeNary2[A, B, R, X, F, True, o], W0].Error -> Piped[_MapNTypes[I, Self.Value, _NativeNary2[A, B, R, X, F, True, o], W0].Out] where I.Element[Self.Value] == A and I.Element[W0] == B:
        """Combine 2 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[I, _ProductTypes[I, Self.Value, W0].Out, _MapNTypes[I, Self.Value, _NativeNary2[A, B, R, X, F, True, o], W0].Out, _MapNTypes[I, Self.Value, _NativeNary2[A, B, R, X, F, True, o], W0].Error](_NativeNary2[A, B, R, X, F, True, o](Pointer(to=function)), self.value^, others^))

    def map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, W1: Movable & Deinitable, //, I: Applicative, F: _Nary3[A0, A1, A2, R]](deinit self, var others: Tuple[W0, W1], ref[o] function: F) raises _MapNTypes[I, Self.Value, _NativeNary3[A0, A1, A2, R, Never, F, False, o], W0, W1].Error -> Piped[_MapNTypes[I, Self.Value, _NativeNary3[A0, A1, A2, R, Never, F, False, o], W0, W1].Out] where I.Element[Self.Value] == A0 and I.Element[W0] == A1 and I.Element[W1] == A2:
        """Combine 3 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[I, _ProductTypes[I, Self.Value, W0, W1].Out, _MapNTypes[I, Self.Value, _NativeNary3[A0, A1, A2, R, Never, F, False, o], W0, W1].Out, _MapNTypes[I, Self.Value, _NativeNary3[A0, A1, A2, R, Never, F, False, o], W0, W1].Error](_NativeNary3[A0, A1, A2, R, Never, F, False, o](Pointer(to=function)), self.value^, others^))

    def map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, W1: Movable & Deinitable, //, I: Applicative, X: Movable & Deinitable, F: _RaisingNary3[A0, A1, A2, R, X]](deinit self, var others: Tuple[W0, W1], ref[o] function: F) raises _MapNTypes[I, Self.Value, _NativeNary3[A0, A1, A2, R, X, F, True, o], W0, W1].Error -> Piped[_MapNTypes[I, Self.Value, _NativeNary3[A0, A1, A2, R, X, F, True, o], W0, W1].Out] where I.Element[Self.Value] == A0 and I.Element[W0] == A1 and I.Element[W1] == A2:
        """Combine 3 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[I, _ProductTypes[I, Self.Value, W0, W1].Out, _MapNTypes[I, Self.Value, _NativeNary3[A0, A1, A2, R, X, F, True, o], W0, W1].Out, _MapNTypes[I, Self.Value, _NativeNary3[A0, A1, A2, R, X, F, True, o], W0, W1].Error](_NativeNary3[A0, A1, A2, R, X, F, True, o](Pointer(to=function)), self.value^, others^))

    def map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, //, I: Applicative, F: _Nary4[A0, A1, A2, A3, R]](deinit self, var others: Tuple[W0, W1, W2], ref[o] function: F) raises _MapNTypes[I, Self.Value, _NativeNary4[A0, A1, A2, A3, R, Never, F, False, o], W0, W1, W2].Error -> Piped[_MapNTypes[I, Self.Value, _NativeNary4[A0, A1, A2, A3, R, Never, F, False, o], W0, W1, W2].Out] where I.Element[Self.Value] == A0 and I.Element[W0] == A1 and I.Element[W1] == A2 and I.Element[W2] == A3:
        """Combine 4 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[I, _ProductTypes[I, Self.Value, W0, W1, W2].Out, _MapNTypes[I, Self.Value, _NativeNary4[A0, A1, A2, A3, R, Never, F, False, o], W0, W1, W2].Out, _MapNTypes[I, Self.Value, _NativeNary4[A0, A1, A2, A3, R, Never, F, False, o], W0, W1, W2].Error](_NativeNary4[A0, A1, A2, A3, R, Never, F, False, o](Pointer(to=function)), self.value^, others^))

    def map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, //, I: Applicative, X: Movable & Deinitable, F: _RaisingNary4[A0, A1, A2, A3, R, X]](deinit self, var others: Tuple[W0, W1, W2], ref[o] function: F) raises _MapNTypes[I, Self.Value, _NativeNary4[A0, A1, A2, A3, R, X, F, True, o], W0, W1, W2].Error -> Piped[_MapNTypes[I, Self.Value, _NativeNary4[A0, A1, A2, A3, R, X, F, True, o], W0, W1, W2].Out] where I.Element[Self.Value] == A0 and I.Element[W0] == A1 and I.Element[W1] == A2 and I.Element[W2] == A3:
        """Combine 4 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[I, _ProductTypes[I, Self.Value, W0, W1, W2].Out, _MapNTypes[I, Self.Value, _NativeNary4[A0, A1, A2, A3, R, X, F, True, o], W0, W1, W2].Out, _MapNTypes[I, Self.Value, _NativeNary4[A0, A1, A2, A3, R, X, F, True, o], W0, W1, W2].Error](_NativeNary4[A0, A1, A2, A3, R, X, F, True, o](Pointer(to=function)), self.value^, others^))

    def map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, W3: Movable & Deinitable, //, I: Applicative, F: _Nary5[A0, A1, A2, A3, A4, R]](deinit self, var others: Tuple[W0, W1, W2, W3], ref[o] function: F) raises _MapNTypes[I, Self.Value, _NativeNary5[A0, A1, A2, A3, A4, R, Never, F, False, o], W0, W1, W2, W3].Error -> Piped[_MapNTypes[I, Self.Value, _NativeNary5[A0, A1, A2, A3, A4, R, Never, F, False, o], W0, W1, W2, W3].Out] where I.Element[Self.Value] == A0 and I.Element[W0] == A1 and I.Element[W1] == A2 and I.Element[W2] == A3 and I.Element[W3] == A4:
        """Combine 5 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[I, _ProductTypes[I, Self.Value, W0, W1, W2, W3].Out, _MapNTypes[I, Self.Value, _NativeNary5[A0, A1, A2, A3, A4, R, Never, F, False, o], W0, W1, W2, W3].Out, _MapNTypes[I, Self.Value, _NativeNary5[A0, A1, A2, A3, A4, R, Never, F, False, o], W0, W1, W2, W3].Error](_NativeNary5[A0, A1, A2, A3, A4, R, Never, F, False, o](Pointer(to=function)), self.value^, others^))

    def map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, W3: Movable & Deinitable, //, I: Applicative, X: Movable & Deinitable, F: _RaisingNary5[A0, A1, A2, A3, A4, R, X]](deinit self, var others: Tuple[W0, W1, W2, W3], ref[o] function: F) raises _MapNTypes[I, Self.Value, _NativeNary5[A0, A1, A2, A3, A4, R, X, F, True, o], W0, W1, W2, W3].Error -> Piped[_MapNTypes[I, Self.Value, _NativeNary5[A0, A1, A2, A3, A4, R, X, F, True, o], W0, W1, W2, W3].Out] where I.Element[Self.Value] == A0 and I.Element[W0] == A1 and I.Element[W1] == A2 and I.Element[W2] == A3 and I.Element[W3] == A4:
        """Combine 5 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[I, _ProductTypes[I, Self.Value, W0, W1, W2, W3].Out, _MapNTypes[I, Self.Value, _NativeNary5[A0, A1, A2, A3, A4, R, X, F, True, o], W0, W1, W2, W3].Out, _MapNTypes[I, Self.Value, _NativeNary5[A0, A1, A2, A3, A4, R, X, F, True, o], W0, W1, W2, W3].Error](_NativeNary5[A0, A1, A2, A3, A4, R, X, F, True, o](Pointer(to=function)), self.value^, others^))

    def map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, W3: Movable & Deinitable, W4: Movable & Deinitable, //, I: Applicative, F: _Nary6[A0, A1, A2, A3, A4, A5, R]](deinit self, var others: Tuple[W0, W1, W2, W3, W4], ref[o] function: F) raises _MapNTypes[I, Self.Value, _NativeNary6[A0, A1, A2, A3, A4, A5, R, Never, F, False, o], W0, W1, W2, W3, W4].Error -> Piped[_MapNTypes[I, Self.Value, _NativeNary6[A0, A1, A2, A3, A4, A5, R, Never, F, False, o], W0, W1, W2, W3, W4].Out] where I.Element[Self.Value] == A0 and I.Element[W0] == A1 and I.Element[W1] == A2 and I.Element[W2] == A3 and I.Element[W3] == A4 and I.Element[W4] == A5:
        """Combine 6 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[I, _ProductTypes[I, Self.Value, W0, W1, W2, W3, W4].Out, _MapNTypes[I, Self.Value, _NativeNary6[A0, A1, A2, A3, A4, A5, R, Never, F, False, o], W0, W1, W2, W3, W4].Out, _MapNTypes[I, Self.Value, _NativeNary6[A0, A1, A2, A3, A4, A5, R, Never, F, False, o], W0, W1, W2, W3, W4].Error](_NativeNary6[A0, A1, A2, A3, A4, A5, R, Never, F, False, o](Pointer(to=function)), self.value^, others^))

    def map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, W3: Movable & Deinitable, W4: Movable & Deinitable, //, I: Applicative, X: Movable & Deinitable, F: _RaisingNary6[A0, A1, A2, A3, A4, A5, R, X]](deinit self, var others: Tuple[W0, W1, W2, W3, W4], ref[o] function: F) raises _MapNTypes[I, Self.Value, _NativeNary6[A0, A1, A2, A3, A4, A5, R, X, F, True, o], W0, W1, W2, W3, W4].Error -> Piped[_MapNTypes[I, Self.Value, _NativeNary6[A0, A1, A2, A3, A4, A5, R, X, F, True, o], W0, W1, W2, W3, W4].Out] where I.Element[Self.Value] == A0 and I.Element[W0] == A1 and I.Element[W1] == A2 and I.Element[W2] == A3 and I.Element[W3] == A4 and I.Element[W4] == A5:
        """Combine 6 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[I, _ProductTypes[I, Self.Value, W0, W1, W2, W3, W4].Out, _MapNTypes[I, Self.Value, _NativeNary6[A0, A1, A2, A3, A4, A5, R, X, F, True, o], W0, W1, W2, W3, W4].Out, _MapNTypes[I, Self.Value, _NativeNary6[A0, A1, A2, A3, A4, A5, R, X, F, True, o], W0, W1, W2, W3, W4].Error](_NativeNary6[A0, A1, A2, A3, A4, A5, R, X, F, True, o](Pointer(to=function)), self.value^, others^))

    def map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, W3: Movable & Deinitable, W4: Movable & Deinitable, W5: Movable & Deinitable, //, I: Applicative, F: _Nary7[A0, A1, A2, A3, A4, A5, A6, R]](deinit self, var others: Tuple[W0, W1, W2, W3, W4, W5], ref[o] function: F) raises _MapNTypes[I, Self.Value, _NativeNary7[A0, A1, A2, A3, A4, A5, A6, R, Never, F, False, o], W0, W1, W2, W3, W4, W5].Error -> Piped[_MapNTypes[I, Self.Value, _NativeNary7[A0, A1, A2, A3, A4, A5, A6, R, Never, F, False, o], W0, W1, W2, W3, W4, W5].Out] where I.Element[Self.Value] == A0 and I.Element[W0] == A1 and I.Element[W1] == A2 and I.Element[W2] == A3 and I.Element[W3] == A4 and I.Element[W4] == A5 and I.Element[W5] == A6:
        """Combine 7 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[I, _ProductTypes[I, Self.Value, W0, W1, W2, W3, W4, W5].Out, _MapNTypes[I, Self.Value, _NativeNary7[A0, A1, A2, A3, A4, A5, A6, R, Never, F, False, o], W0, W1, W2, W3, W4, W5].Out, _MapNTypes[I, Self.Value, _NativeNary7[A0, A1, A2, A3, A4, A5, A6, R, Never, F, False, o], W0, W1, W2, W3, W4, W5].Error](_NativeNary7[A0, A1, A2, A3, A4, A5, A6, R, Never, F, False, o](Pointer(to=function)), self.value^, others^))

    def map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, W3: Movable & Deinitable, W4: Movable & Deinitable, W5: Movable & Deinitable, //, I: Applicative, X: Movable & Deinitable, F: _RaisingNary7[A0, A1, A2, A3, A4, A5, A6, R, X]](deinit self, var others: Tuple[W0, W1, W2, W3, W4, W5], ref[o] function: F) raises _MapNTypes[I, Self.Value, _NativeNary7[A0, A1, A2, A3, A4, A5, A6, R, X, F, True, o], W0, W1, W2, W3, W4, W5].Error -> Piped[_MapNTypes[I, Self.Value, _NativeNary7[A0, A1, A2, A3, A4, A5, A6, R, X, F, True, o], W0, W1, W2, W3, W4, W5].Out] where I.Element[Self.Value] == A0 and I.Element[W0] == A1 and I.Element[W1] == A2 and I.Element[W2] == A3 and I.Element[W3] == A4 and I.Element[W4] == A5 and I.Element[W5] == A6:
        """Combine 7 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[I, _ProductTypes[I, Self.Value, W0, W1, W2, W3, W4, W5].Out, _MapNTypes[I, Self.Value, _NativeNary7[A0, A1, A2, A3, A4, A5, A6, R, X, F, True, o], W0, W1, W2, W3, W4, W5].Out, _MapNTypes[I, Self.Value, _NativeNary7[A0, A1, A2, A3, A4, A5, A6, R, X, F, True, o], W0, W1, W2, W3, W4, W5].Error](_NativeNary7[A0, A1, A2, A3, A4, A5, A6, R, X, F, True, o](Pointer(to=function)), self.value^, others^))

    def map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, W3: Movable & Deinitable, W4: Movable & Deinitable, W5: Movable & Deinitable, W6: Movable & Deinitable, //, I: Applicative, F: _Nary8[A0, A1, A2, A3, A4, A5, A6, A7, R]](deinit self, var others: Tuple[W0, W1, W2, W3, W4, W5, W6], ref[o] function: F) raises _MapNTypes[I, Self.Value, _NativeNary8[A0, A1, A2, A3, A4, A5, A6, A7, R, Never, F, False, o], W0, W1, W2, W3, W4, W5, W6].Error -> Piped[_MapNTypes[I, Self.Value, _NativeNary8[A0, A1, A2, A3, A4, A5, A6, A7, R, Never, F, False, o], W0, W1, W2, W3, W4, W5, W6].Out] where I.Element[Self.Value] == A0 and I.Element[W0] == A1 and I.Element[W1] == A2 and I.Element[W2] == A3 and I.Element[W3] == A4 and I.Element[W4] == A5 and I.Element[W5] == A6 and I.Element[W6] == A7:
        """Combine 8 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[I, _ProductTypes[I, Self.Value, W0, W1, W2, W3, W4, W5, W6].Out, _MapNTypes[I, Self.Value, _NativeNary8[A0, A1, A2, A3, A4, A5, A6, A7, R, Never, F, False, o], W0, W1, W2, W3, W4, W5, W6].Out, _MapNTypes[I, Self.Value, _NativeNary8[A0, A1, A2, A3, A4, A5, A6, A7, R, Never, F, False, o], W0, W1, W2, W3, W4, W5, W6].Error](_NativeNary8[A0, A1, A2, A3, A4, A5, A6, A7, R, Never, F, False, o](Pointer(to=function)), self.value^, others^))

    def map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, W3: Movable & Deinitable, W4: Movable & Deinitable, W5: Movable & Deinitable, W6: Movable & Deinitable, //, I: Applicative, X: Movable & Deinitable, F: _RaisingNary8[A0, A1, A2, A3, A4, A5, A6, A7, R, X]](deinit self, var others: Tuple[W0, W1, W2, W3, W4, W5, W6], ref[o] function: F) raises _MapNTypes[I, Self.Value, _NativeNary8[A0, A1, A2, A3, A4, A5, A6, A7, R, X, F, True, o], W0, W1, W2, W3, W4, W5, W6].Error -> Piped[_MapNTypes[I, Self.Value, _NativeNary8[A0, A1, A2, A3, A4, A5, A6, A7, R, X, F, True, o], W0, W1, W2, W3, W4, W5, W6].Out] where I.Element[Self.Value] == A0 and I.Element[W0] == A1 and I.Element[W1] == A2 and I.Element[W2] == A3 and I.Element[W3] == A4 and I.Element[W4] == A5 and I.Element[W5] == A6 and I.Element[W6] == A7:
        """Combine 8 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[I, _ProductTypes[I, Self.Value, W0, W1, W2, W3, W4, W5, W6].Out, _MapNTypes[I, Self.Value, _NativeNary8[A0, A1, A2, A3, A4, A5, A6, A7, R, X, F, True, o], W0, W1, W2, W3, W4, W5, W6].Out, _MapNTypes[I, Self.Value, _NativeNary8[A0, A1, A2, A3, A4, A5, A6, A7, R, X, F, True, o], W0, W1, W2, W3, W4, W5, W6].Error](_NativeNary8[A0, A1, A2, A3, A4, A5, A6, A7, R, X, F, True, o](Pointer(to=function)), self.value^, others^))

    def product_n[*Ws: Movable & Deinitable](deinit self, var others: Tuple[*Ws]) raises Never -> Piped[_InferredApplicative[Self.Value].Pure[_ProductRun[_InferredApplicative[Self.Value], Self.Value, *Ws].Payload]] where Self.Value == _InferredApplicative[Self.Value].Pure[_InferredApplicative[Self.Value].Element[Self.Value]] and _ProductRun[_InferredApplicative[Self.Value], Self.Value, *Ws].NativeInputs:
        """Combine the receiver and additional operands into flat tuples.

        Parameters:
            Ws: The exact additional carrier types, including origins.

        Args:
            others: The tuple of already evaluated additional operands, consumed.

        Returns:
            The family of flat tuples in receiver-first order. No additional
            operands produces one-element tuples. List uses Cartesian ordering.

        Raises:
            The exact family construction error; stored Result errors remain data.
        """
        return Piped(_ProductRun[_InferredApplicative[Self.Value], Self.Value, *Ws].run[_InferredApplicative[Self.Value].Pure[_ProductRun[_InferredApplicative[Self.Value], Self.Value, *Ws].Payload], Never](self.value^, others^))

    def map_n[F: UnaryContract & Movable & Deinitable, *Ws: Movable & Deinitable](deinit self, var others: Tuple[*Ws], var function: F) raises F.Error -> Piped[_InferredApplicative[Self.Value].Pure[F.Out]] where Self.Value == _InferredApplicative[Self.Value].Pure[_InferredApplicative[Self.Value].Element[Self.Value]] and _ProductRun[_InferredApplicative[Self.Value], Self.Value, *Ws].NativeInputs and F.Arg == _ProductRun[_InferredApplicative[Self.Value], Self.Value, *Ws].Payload:
        """Combine operands, then map a callback over each flat tuple of payloads.

        Native callbacks take one argument per operand, from one to eight.
        Library Unary callbacks consume the whole tuple in their receiver mode.

        Parameters:
            F: The tuple callback, retaining its exact argument, result and error.
            Ws: The exact additional carrier types, including origins.

        Args:
            others: The already evaluated additional operands, consumed.
            function: The callback, consumed; native callbacks are borrowed.

        Returns:
            The family of callback results; absence or failure skips the callback.
            List materializes the Cartesian tuples before mapping them in order.

        Raises:
            The exact callback or family construction error, without conversion.
        """
        return Piped(_map_n_as[_InferredApplicative[Self.Value], _InferredApplicative[Self.Value].Pure[_ProductRun[_InferredApplicative[Self.Value], Self.Value, *Ws].Payload], _InferredApplicative[Self.Value].Pure[F.Out], F.Error](function^, self.value^, others^))

    def map_n[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, var others: Tuple[], ref[o] function: F) raises Never -> Piped[_InferredApplicative[Self.Value].Pure[R]] where Self.Value == _InferredApplicative[Self.Value].Pure[_InferredApplicative[Self.Value].Element[Self.Value]] and _ProductRun[_InferredApplicative[Self.Value], Self.Value].NativeInputs and _InferredApplicative[Self.Value].Element[Self.Value] == A:
        """Combine 1 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[_InferredApplicative[Self.Value], _InferredApplicative[Self.Value].Pure[_ProductRun[_InferredApplicative[Self.Value], Self.Value].Payload], _InferredApplicative[Self.Value].Pure[R], Never](_NativeNary1[A, R, Never, F, False, o](Pointer(to=function)), self.value^, others^))

    def map_n[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, X: Movable & Deinitable, F: _RaisingUnary[A, R, X]](deinit self, var others: Tuple[], ref[o] function: F) raises X -> Piped[_InferredApplicative[Self.Value].Pure[R]] where Self.Value == _InferredApplicative[Self.Value].Pure[_InferredApplicative[Self.Value].Element[Self.Value]] and _ProductRun[_InferredApplicative[Self.Value], Self.Value].NativeInputs and _InferredApplicative[Self.Value].Element[Self.Value] == A:
        """Combine 1 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[_InferredApplicative[Self.Value], _InferredApplicative[Self.Value].Pure[_ProductRun[_InferredApplicative[Self.Value], Self.Value].Payload], _InferredApplicative[Self.Value].Pure[R], X](_NativeNary1[A, R, X, F, True, o](Pointer(to=function)), self.value^, others^))

    def map_n[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, //, F: _Binary[A, B, R]](deinit self, var others: Tuple[W0], ref[o] function: F) raises Never -> Piped[_InferredApplicative[Self.Value].Pure[R]] where Self.Value == _InferredApplicative[Self.Value].Pure[_InferredApplicative[Self.Value].Element[Self.Value]] and _ProductRun[_InferredApplicative[Self.Value], Self.Value, W0].NativeInputs and _InferredApplicative[Self.Value].Element[Self.Value] == A and _InferredApplicative[Self.Value].Element[W0] == B:
        """Combine 2 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[_InferredApplicative[Self.Value], _InferredApplicative[Self.Value].Pure[_ProductRun[_InferredApplicative[Self.Value], Self.Value, W0].Payload], _InferredApplicative[Self.Value].Pure[R], Never](_NativeNary2[A, B, R, Never, F, False, o](Pointer(to=function)), self.value^, others^))

    def map_n[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, //, X: Movable & Deinitable, F: _RaisingBinary[A, B, R, X]](deinit self, var others: Tuple[W0], ref[o] function: F) raises X -> Piped[_InferredApplicative[Self.Value].Pure[R]] where Self.Value == _InferredApplicative[Self.Value].Pure[_InferredApplicative[Self.Value].Element[Self.Value]] and _ProductRun[_InferredApplicative[Self.Value], Self.Value, W0].NativeInputs and _InferredApplicative[Self.Value].Element[Self.Value] == A and _InferredApplicative[Self.Value].Element[W0] == B:
        """Combine 2 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[_InferredApplicative[Self.Value], _InferredApplicative[Self.Value].Pure[_ProductRun[_InferredApplicative[Self.Value], Self.Value, W0].Payload], _InferredApplicative[Self.Value].Pure[R], X](_NativeNary2[A, B, R, X, F, True, o](Pointer(to=function)), self.value^, others^))

    def map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, W1: Movable & Deinitable, //, F: _Nary3[A0, A1, A2, R]](deinit self, var others: Tuple[W0, W1], ref[o] function: F) raises Never -> Piped[_InferredApplicative[Self.Value].Pure[R]] where Self.Value == _InferredApplicative[Self.Value].Pure[_InferredApplicative[Self.Value].Element[Self.Value]] and _ProductRun[_InferredApplicative[Self.Value], Self.Value, W0, W1].NativeInputs and _InferredApplicative[Self.Value].Element[Self.Value] == A0 and _InferredApplicative[Self.Value].Element[W0] == A1 and _InferredApplicative[Self.Value].Element[W1] == A2:
        """Combine 3 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[_InferredApplicative[Self.Value], _InferredApplicative[Self.Value].Pure[_ProductRun[_InferredApplicative[Self.Value], Self.Value, W0, W1].Payload], _InferredApplicative[Self.Value].Pure[R], Never](_NativeNary3[A0, A1, A2, R, Never, F, False, o](Pointer(to=function)), self.value^, others^))

    def map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, W1: Movable & Deinitable, //, X: Movable & Deinitable, F: _RaisingNary3[A0, A1, A2, R, X]](deinit self, var others: Tuple[W0, W1], ref[o] function: F) raises X -> Piped[_InferredApplicative[Self.Value].Pure[R]] where Self.Value == _InferredApplicative[Self.Value].Pure[_InferredApplicative[Self.Value].Element[Self.Value]] and _ProductRun[_InferredApplicative[Self.Value], Self.Value, W0, W1].NativeInputs and _InferredApplicative[Self.Value].Element[Self.Value] == A0 and _InferredApplicative[Self.Value].Element[W0] == A1 and _InferredApplicative[Self.Value].Element[W1] == A2:
        """Combine 3 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[_InferredApplicative[Self.Value], _InferredApplicative[Self.Value].Pure[_ProductRun[_InferredApplicative[Self.Value], Self.Value, W0, W1].Payload], _InferredApplicative[Self.Value].Pure[R], X](_NativeNary3[A0, A1, A2, R, X, F, True, o](Pointer(to=function)), self.value^, others^))

    def map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, //, F: _Nary4[A0, A1, A2, A3, R]](deinit self, var others: Tuple[W0, W1, W2], ref[o] function: F) raises Never -> Piped[_InferredApplicative[Self.Value].Pure[R]] where Self.Value == _InferredApplicative[Self.Value].Pure[_InferredApplicative[Self.Value].Element[Self.Value]] and _ProductRun[_InferredApplicative[Self.Value], Self.Value, W0, W1, W2].NativeInputs and _InferredApplicative[Self.Value].Element[Self.Value] == A0 and _InferredApplicative[Self.Value].Element[W0] == A1 and _InferredApplicative[Self.Value].Element[W1] == A2 and _InferredApplicative[Self.Value].Element[W2] == A3:
        """Combine 4 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[_InferredApplicative[Self.Value], _InferredApplicative[Self.Value].Pure[_ProductRun[_InferredApplicative[Self.Value], Self.Value, W0, W1, W2].Payload], _InferredApplicative[Self.Value].Pure[R], Never](_NativeNary4[A0, A1, A2, A3, R, Never, F, False, o](Pointer(to=function)), self.value^, others^))

    def map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, //, X: Movable & Deinitable, F: _RaisingNary4[A0, A1, A2, A3, R, X]](deinit self, var others: Tuple[W0, W1, W2], ref[o] function: F) raises X -> Piped[_InferredApplicative[Self.Value].Pure[R]] where Self.Value == _InferredApplicative[Self.Value].Pure[_InferredApplicative[Self.Value].Element[Self.Value]] and _ProductRun[_InferredApplicative[Self.Value], Self.Value, W0, W1, W2].NativeInputs and _InferredApplicative[Self.Value].Element[Self.Value] == A0 and _InferredApplicative[Self.Value].Element[W0] == A1 and _InferredApplicative[Self.Value].Element[W1] == A2 and _InferredApplicative[Self.Value].Element[W2] == A3:
        """Combine 4 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[_InferredApplicative[Self.Value], _InferredApplicative[Self.Value].Pure[_ProductRun[_InferredApplicative[Self.Value], Self.Value, W0, W1, W2].Payload], _InferredApplicative[Self.Value].Pure[R], X](_NativeNary4[A0, A1, A2, A3, R, X, F, True, o](Pointer(to=function)), self.value^, others^))

    def map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, W3: Movable & Deinitable, //, F: _Nary5[A0, A1, A2, A3, A4, R]](deinit self, var others: Tuple[W0, W1, W2, W3], ref[o] function: F) raises Never -> Piped[_InferredApplicative[Self.Value].Pure[R]] where Self.Value == _InferredApplicative[Self.Value].Pure[_InferredApplicative[Self.Value].Element[Self.Value]] and _ProductRun[_InferredApplicative[Self.Value], Self.Value, W0, W1, W2, W3].NativeInputs and _InferredApplicative[Self.Value].Element[Self.Value] == A0 and _InferredApplicative[Self.Value].Element[W0] == A1 and _InferredApplicative[Self.Value].Element[W1] == A2 and _InferredApplicative[Self.Value].Element[W2] == A3 and _InferredApplicative[Self.Value].Element[W3] == A4:
        """Combine 5 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[_InferredApplicative[Self.Value], _InferredApplicative[Self.Value].Pure[_ProductRun[_InferredApplicative[Self.Value], Self.Value, W0, W1, W2, W3].Payload], _InferredApplicative[Self.Value].Pure[R], Never](_NativeNary5[A0, A1, A2, A3, A4, R, Never, F, False, o](Pointer(to=function)), self.value^, others^))

    def map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, W3: Movable & Deinitable, //, X: Movable & Deinitable, F: _RaisingNary5[A0, A1, A2, A3, A4, R, X]](deinit self, var others: Tuple[W0, W1, W2, W3], ref[o] function: F) raises X -> Piped[_InferredApplicative[Self.Value].Pure[R]] where Self.Value == _InferredApplicative[Self.Value].Pure[_InferredApplicative[Self.Value].Element[Self.Value]] and _ProductRun[_InferredApplicative[Self.Value], Self.Value, W0, W1, W2, W3].NativeInputs and _InferredApplicative[Self.Value].Element[Self.Value] == A0 and _InferredApplicative[Self.Value].Element[W0] == A1 and _InferredApplicative[Self.Value].Element[W1] == A2 and _InferredApplicative[Self.Value].Element[W2] == A3 and _InferredApplicative[Self.Value].Element[W3] == A4:
        """Combine 5 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[_InferredApplicative[Self.Value], _InferredApplicative[Self.Value].Pure[_ProductRun[_InferredApplicative[Self.Value], Self.Value, W0, W1, W2, W3].Payload], _InferredApplicative[Self.Value].Pure[R], X](_NativeNary5[A0, A1, A2, A3, A4, R, X, F, True, o](Pointer(to=function)), self.value^, others^))

    def map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, W3: Movable & Deinitable, W4: Movable & Deinitable, //, F: _Nary6[A0, A1, A2, A3, A4, A5, R]](deinit self, var others: Tuple[W0, W1, W2, W3, W4], ref[o] function: F) raises Never -> Piped[_InferredApplicative[Self.Value].Pure[R]] where Self.Value == _InferredApplicative[Self.Value].Pure[_InferredApplicative[Self.Value].Element[Self.Value]] and _ProductRun[_InferredApplicative[Self.Value], Self.Value, W0, W1, W2, W3, W4].NativeInputs and _InferredApplicative[Self.Value].Element[Self.Value] == A0 and _InferredApplicative[Self.Value].Element[W0] == A1 and _InferredApplicative[Self.Value].Element[W1] == A2 and _InferredApplicative[Self.Value].Element[W2] == A3 and _InferredApplicative[Self.Value].Element[W3] == A4 and _InferredApplicative[Self.Value].Element[W4] == A5:
        """Combine 6 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[_InferredApplicative[Self.Value], _InferredApplicative[Self.Value].Pure[_ProductRun[_InferredApplicative[Self.Value], Self.Value, W0, W1, W2, W3, W4].Payload], _InferredApplicative[Self.Value].Pure[R], Never](_NativeNary6[A0, A1, A2, A3, A4, A5, R, Never, F, False, o](Pointer(to=function)), self.value^, others^))

    def map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, W3: Movable & Deinitable, W4: Movable & Deinitable, //, X: Movable & Deinitable, F: _RaisingNary6[A0, A1, A2, A3, A4, A5, R, X]](deinit self, var others: Tuple[W0, W1, W2, W3, W4], ref[o] function: F) raises X -> Piped[_InferredApplicative[Self.Value].Pure[R]] where Self.Value == _InferredApplicative[Self.Value].Pure[_InferredApplicative[Self.Value].Element[Self.Value]] and _ProductRun[_InferredApplicative[Self.Value], Self.Value, W0, W1, W2, W3, W4].NativeInputs and _InferredApplicative[Self.Value].Element[Self.Value] == A0 and _InferredApplicative[Self.Value].Element[W0] == A1 and _InferredApplicative[Self.Value].Element[W1] == A2 and _InferredApplicative[Self.Value].Element[W2] == A3 and _InferredApplicative[Self.Value].Element[W3] == A4 and _InferredApplicative[Self.Value].Element[W4] == A5:
        """Combine 6 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[_InferredApplicative[Self.Value], _InferredApplicative[Self.Value].Pure[_ProductRun[_InferredApplicative[Self.Value], Self.Value, W0, W1, W2, W3, W4].Payload], _InferredApplicative[Self.Value].Pure[R], X](_NativeNary6[A0, A1, A2, A3, A4, A5, R, X, F, True, o](Pointer(to=function)), self.value^, others^))

    def map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, W3: Movable & Deinitable, W4: Movable & Deinitable, W5: Movable & Deinitable, //, F: _Nary7[A0, A1, A2, A3, A4, A5, A6, R]](deinit self, var others: Tuple[W0, W1, W2, W3, W4, W5], ref[o] function: F) raises Never -> Piped[_InferredApplicative[Self.Value].Pure[R]] where Self.Value == _InferredApplicative[Self.Value].Pure[_InferredApplicative[Self.Value].Element[Self.Value]] and _ProductRun[_InferredApplicative[Self.Value], Self.Value, W0, W1, W2, W3, W4, W5].NativeInputs and _InferredApplicative[Self.Value].Element[Self.Value] == A0 and _InferredApplicative[Self.Value].Element[W0] == A1 and _InferredApplicative[Self.Value].Element[W1] == A2 and _InferredApplicative[Self.Value].Element[W2] == A3 and _InferredApplicative[Self.Value].Element[W3] == A4 and _InferredApplicative[Self.Value].Element[W4] == A5 and _InferredApplicative[Self.Value].Element[W5] == A6:
        """Combine 7 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[_InferredApplicative[Self.Value], _InferredApplicative[Self.Value].Pure[_ProductRun[_InferredApplicative[Self.Value], Self.Value, W0, W1, W2, W3, W4, W5].Payload], _InferredApplicative[Self.Value].Pure[R], Never](_NativeNary7[A0, A1, A2, A3, A4, A5, A6, R, Never, F, False, o](Pointer(to=function)), self.value^, others^))

    def map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, W3: Movable & Deinitable, W4: Movable & Deinitable, W5: Movable & Deinitable, //, X: Movable & Deinitable, F: _RaisingNary7[A0, A1, A2, A3, A4, A5, A6, R, X]](deinit self, var others: Tuple[W0, W1, W2, W3, W4, W5], ref[o] function: F) raises X -> Piped[_InferredApplicative[Self.Value].Pure[R]] where Self.Value == _InferredApplicative[Self.Value].Pure[_InferredApplicative[Self.Value].Element[Self.Value]] and _ProductRun[_InferredApplicative[Self.Value], Self.Value, W0, W1, W2, W3, W4, W5].NativeInputs and _InferredApplicative[Self.Value].Element[Self.Value] == A0 and _InferredApplicative[Self.Value].Element[W0] == A1 and _InferredApplicative[Self.Value].Element[W1] == A2 and _InferredApplicative[Self.Value].Element[W2] == A3 and _InferredApplicative[Self.Value].Element[W3] == A4 and _InferredApplicative[Self.Value].Element[W4] == A5 and _InferredApplicative[Self.Value].Element[W5] == A6:
        """Combine 7 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[_InferredApplicative[Self.Value], _InferredApplicative[Self.Value].Pure[_ProductRun[_InferredApplicative[Self.Value], Self.Value, W0, W1, W2, W3, W4, W5].Payload], _InferredApplicative[Self.Value].Pure[R], X](_NativeNary7[A0, A1, A2, A3, A4, A5, A6, R, X, F, True, o](Pointer(to=function)), self.value^, others^))

    def map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, W3: Movable & Deinitable, W4: Movable & Deinitable, W5: Movable & Deinitable, W6: Movable & Deinitable, //, F: _Nary8[A0, A1, A2, A3, A4, A5, A6, A7, R]](deinit self, var others: Tuple[W0, W1, W2, W3, W4, W5, W6], ref[o] function: F) raises Never -> Piped[_InferredApplicative[Self.Value].Pure[R]] where Self.Value == _InferredApplicative[Self.Value].Pure[_InferredApplicative[Self.Value].Element[Self.Value]] and _ProductRun[_InferredApplicative[Self.Value], Self.Value, W0, W1, W2, W3, W4, W5, W6].NativeInputs and _InferredApplicative[Self.Value].Element[Self.Value] == A0 and _InferredApplicative[Self.Value].Element[W0] == A1 and _InferredApplicative[Self.Value].Element[W1] == A2 and _InferredApplicative[Self.Value].Element[W2] == A3 and _InferredApplicative[Self.Value].Element[W3] == A4 and _InferredApplicative[Self.Value].Element[W4] == A5 and _InferredApplicative[Self.Value].Element[W5] == A6 and _InferredApplicative[Self.Value].Element[W6] == A7:
        """Combine 8 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[_InferredApplicative[Self.Value], _InferredApplicative[Self.Value].Pure[_ProductRun[_InferredApplicative[Self.Value], Self.Value, W0, W1, W2, W3, W4, W5, W6].Payload], _InferredApplicative[Self.Value].Pure[R], Never](_NativeNary8[A0, A1, A2, A3, A4, A5, A6, A7, R, Never, F, False, o](Pointer(to=function)), self.value^, others^))

    def map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, W3: Movable & Deinitable, W4: Movable & Deinitable, W5: Movable & Deinitable, W6: Movable & Deinitable, //, X: Movable & Deinitable, F: _RaisingNary8[A0, A1, A2, A3, A4, A5, A6, A7, R, X]](deinit self, var others: Tuple[W0, W1, W2, W3, W4, W5, W6], ref[o] function: F) raises X -> Piped[_InferredApplicative[Self.Value].Pure[R]] where Self.Value == _InferredApplicative[Self.Value].Pure[_InferredApplicative[Self.Value].Element[Self.Value]] and _ProductRun[_InferredApplicative[Self.Value], Self.Value, W0, W1, W2, W3, W4, W5, W6].NativeInputs and _InferredApplicative[Self.Value].Element[Self.Value] == A0 and _InferredApplicative[Self.Value].Element[W0] == A1 and _InferredApplicative[Self.Value].Element[W1] == A2 and _InferredApplicative[Self.Value].Element[W2] == A3 and _InferredApplicative[Self.Value].Element[W3] == A4 and _InferredApplicative[Self.Value].Element[W4] == A5 and _InferredApplicative[Self.Value].Element[W5] == A6 and _InferredApplicative[Self.Value].Element[W6] == A7:
        """Combine 8 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[_InferredApplicative[Self.Value], _InferredApplicative[Self.Value].Pure[_ProductRun[_InferredApplicative[Self.Value], Self.Value, W0, W1, W2, W3, W4, W5, W6].Payload], _InferredApplicative[Self.Value].Pure[R], X](_NativeNary8[A0, A1, A2, A3, A4, A5, A6, A7, R, X, F, True, o](Pointer(to=function)), self.value^, others^))

    def par_product_n[S: Semigroup, *Ws: Movable & Deinitable](deinit self, var others: Tuple[*Ws]) raises (S.Error if Ws.length > 0 else Never) -> Piped[ValidationFamily[S].Pure[_ProductRun[ValidationFamily[S], Self.Value, *Ws].Payload]] where Self.Value == ValidationFamily[S].Pure[ValidationFamily[S].Element[Self.Value]] and _ProductRun[ValidationFamily[S], Self.Value, *Ws].NativeInputs:
        """Combine the receiver and additional operands into flat tuples.

        Parameters:
            S: The error Semigroup; inferred list errors concatenate by default.
            Ws: The exact additional carrier types, including origins.

        Args:
            others: The tuple of already evaluated additional operands, consumed.

        Returns:
            A Result of a flat tuple in receiver-first order, or accumulated
            stored errors. No additional operands produces a one-element tuple.

        Raises:
            The exact error-combination error; Never with no additional
            operands. Stored Result errors remain data.
        """
        return Piped(_ProductRun[ValidationFamily[S], Self.Value, *Ws].run[ValidationFamily[S].Pure[_ProductRun[ValidationFamily[S], Self.Value, *Ws].Payload], (S.Error if Ws.length > 0 else Never)](self.value^, others^))

    def par_product_n[*Ws: Movable & Deinitable](deinit self, var others: Tuple[*Ws]) raises (_ListErrors[Self.Value].Error if Ws.length > 0 else Never) -> Piped[ValidationFamily[_ListErrors[Self.Value]].Pure[_ProductRun[ValidationFamily[_ListErrors[Self.Value]], Self.Value, *Ws].Payload]] where Self.Value == ValidationFamily[_ListErrors[Self.Value]].Pure[ValidationFamily[_ListErrors[Self.Value]].Element[Self.Value]] and _ProductRun[ValidationFamily[_ListErrors[Self.Value]], Self.Value, *Ws].NativeInputs:
        """Combine the receiver and additional operands into flat tuples.

        Parameters:
            Ws: The exact additional carrier types, including origins.

        Args:
            others: The tuple of already evaluated additional operands, consumed.

        Returns:
            A Result of a flat tuple in receiver-first order, or accumulated
            stored errors. No additional operands produces a one-element tuple.

        Raises:
            The exact error-combination error; Never with no additional
            operands. Stored Result errors remain data.
        """
        return Piped(_ProductRun[ValidationFamily[_ListErrors[Self.Value]], Self.Value, *Ws].run[ValidationFamily[_ListErrors[Self.Value]].Pure[_ProductRun[ValidationFamily[_ListErrors[Self.Value]], Self.Value, *Ws].Payload], (_ListErrors[Self.Value].Error if Ws.length > 0 else Never)](self.value^, others^))

    def par_map_n[F: UnaryContract & Movable & Deinitable, //, S: Semigroup, *Ws: Movable & Deinitable](deinit self, var others: Tuple[*Ws], var function: F) raises (_CommonError[S.Error, F.Error] if Ws.length > 0 else F.Error) -> Piped[ValidationFamily[S].Pure[F.Out]] where Self.Value == ValidationFamily[S].Pure[ValidationFamily[S].Element[Self.Value]] and _ProductRun[ValidationFamily[S], Self.Value, *Ws].NativeInputs and (_ErrorCompatible[_CommonError[S.Error, F.Error], F.Error] if Ws.length > 0 else True) and F.Arg == _ProductRun[ValidationFamily[S], Self.Value, *Ws].Payload:
        """Combine independent Results, accumulating their stored errors in order.

        Native callbacks take one argument per operand, from one to eight.
        Library Unary callbacks consume the whole tuple in their receiver mode.

        Parameters:
            F: The tuple callback, retaining its exact argument, result and error.
            S: The error Semigroup; inferred list errors concatenate by default.
            Ws: The exact additional carrier types, including origins.

        Args:
            others: The already evaluated additional operands, consumed.
            function: The callback, consumed; native callbacks are borrowed.

        Returns:
            A Result of the callback output, or all stored errors combined in
            receiver-first order. The callback runs once only if every input is Ok.

        Raises:
            The exact callback or family construction error, without conversion.
        """
        return Piped(_map_n_as[ValidationFamily[S], ValidationFamily[S].Pure[_ProductRun[ValidationFamily[S], Self.Value, *Ws].Payload], ValidationFamily[S].Pure[F.Out], (_CommonError[S.Error, F.Error] if Ws.length > 0 else F.Error)](function^, self.value^, others^))

    def par_map_n[F: UnaryContract & Movable & Deinitable, *Ws: Movable & Deinitable](deinit self, var others: Tuple[*Ws], var function: F) raises (_CommonError[_ListErrors[Self.Value].Error, F.Error] if Ws.length > 0 else F.Error) -> Piped[ValidationFamily[_ListErrors[Self.Value]].Pure[F.Out]] where Self.Value == ValidationFamily[_ListErrors[Self.Value]].Pure[ValidationFamily[_ListErrors[Self.Value]].Element[Self.Value]] and _ProductRun[ValidationFamily[_ListErrors[Self.Value]], Self.Value, *Ws].NativeInputs and (_ErrorCompatible[_CommonError[_ListErrors[Self.Value].Error, F.Error], F.Error] if Ws.length > 0 else True) and F.Arg == _ProductRun[ValidationFamily[_ListErrors[Self.Value]], Self.Value, *Ws].Payload:
        """Combine independent Results, accumulating their stored errors in order.

        Native callbacks take one argument per operand, from one to eight.
        Library Unary callbacks consume the whole tuple in their receiver mode.

        Parameters:
            F: The tuple callback, retaining its exact argument, result and error.
            Ws: The exact additional carrier types, including origins.

        Args:
            others: The already evaluated additional operands, consumed.
            function: The callback, consumed; native callbacks are borrowed.

        Returns:
            A Result of the callback output, or all stored errors combined in
            receiver-first order. The callback runs once only if every input is Ok.

        Raises:
            The exact callback or family construction error, without conversion.
        """
        return Piped(_map_n_as[ValidationFamily[_ListErrors[Self.Value]], ValidationFamily[_ListErrors[Self.Value]].Pure[_ProductRun[ValidationFamily[_ListErrors[Self.Value]], Self.Value, *Ws].Payload], ValidationFamily[_ListErrors[Self.Value]].Pure[F.Out], (_CommonError[_ListErrors[Self.Value].Error, F.Error] if Ws.length > 0 else F.Error)](function^, self.value^, others^))

    def par_map_n[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, F: _Unary[A, R], //, S: Semigroup = _ListErrors[Self.Value]](deinit self, var others: Tuple[], ref[o] function: F) raises Never -> Piped[ValidationFamily[S].Pure[R]] where Self.Value == ValidationFamily[S].Pure[ValidationFamily[S].Element[Self.Value]] and _ProductRun[ValidationFamily[S], Self.Value].NativeInputs and ValidationFamily[S].Element[Self.Value] == A:
        """Combine 1 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[ValidationFamily[S], ValidationFamily[S].Pure[_ProductRun[ValidationFamily[S], Self.Value].Payload], ValidationFamily[S].Pure[R], Never](_NativeNary1[A, R, Never, F, False, o](Pointer(to=function)), self.value^, others^))

    def par_map_n[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, X: Movable & Deinitable, F: _RaisingUnary[A, R, X], //, S: Semigroup = _ListErrors[Self.Value]](deinit self, var others: Tuple[], ref[o] function: F) raises X -> Piped[ValidationFamily[S].Pure[R]] where Self.Value == ValidationFamily[S].Pure[ValidationFamily[S].Element[Self.Value]] and _ProductRun[ValidationFamily[S], Self.Value].NativeInputs and ValidationFamily[S].Element[Self.Value] == A:
        """Combine 1 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[ValidationFamily[S], ValidationFamily[S].Pure[_ProductRun[ValidationFamily[S], Self.Value].Payload], ValidationFamily[S].Pure[R], X](_NativeNary1[A, R, X, F, True, o](Pointer(to=function)), self.value^, others^))

    def par_map_n[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, F: _Binary[A, B, R], W0: Movable & Deinitable, //, S: Semigroup = _ListErrors[Self.Value]](deinit self, var others: Tuple[W0], ref[o] function: F) raises _CommonError[S.Error, Never] -> Piped[ValidationFamily[S].Pure[R]] where Self.Value == ValidationFamily[S].Pure[ValidationFamily[S].Element[Self.Value]] and _ProductRun[ValidationFamily[S], Self.Value, W0].NativeInputs and ValidationFamily[S].Element[Self.Value] == A and ValidationFamily[S].Element[W0] == B and _ErrorCompatible[_CommonError[S.Error, Never], Never]:
        """Combine 2 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[ValidationFamily[S], ValidationFamily[S].Pure[_ProductRun[ValidationFamily[S], Self.Value, W0].Payload], ValidationFamily[S].Pure[R], _CommonError[S.Error, Never]](_NativeNary2[A, B, R, Never, F, False, o](Pointer(to=function)), self.value^, others^))

    def par_map_n[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, X: Movable & Deinitable, F: _RaisingBinary[A, B, R, X], W0: Movable & Deinitable, //, S: Semigroup = _ListErrors[Self.Value]](deinit self, var others: Tuple[W0], ref[o] function: F) raises _CommonError[S.Error, X] -> Piped[ValidationFamily[S].Pure[R]] where Self.Value == ValidationFamily[S].Pure[ValidationFamily[S].Element[Self.Value]] and _ProductRun[ValidationFamily[S], Self.Value, W0].NativeInputs and ValidationFamily[S].Element[Self.Value] == A and ValidationFamily[S].Element[W0] == B and _ErrorCompatible[_CommonError[S.Error, X], X]:
        """Combine 2 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[ValidationFamily[S], ValidationFamily[S].Pure[_ProductRun[ValidationFamily[S], Self.Value, W0].Payload], ValidationFamily[S].Pure[R], _CommonError[S.Error, X]](_NativeNary2[A, B, R, X, F, True, o](Pointer(to=function)), self.value^, others^))

    def par_map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, F: _Nary3[A0, A1, A2, R], W0: Movable & Deinitable, W1: Movable & Deinitable, //, S: Semigroup = _ListErrors[Self.Value]](deinit self, var others: Tuple[W0, W1], ref[o] function: F) raises _CommonError[S.Error, Never] -> Piped[ValidationFamily[S].Pure[R]] where Self.Value == ValidationFamily[S].Pure[ValidationFamily[S].Element[Self.Value]] and _ProductRun[ValidationFamily[S], Self.Value, W0, W1].NativeInputs and ValidationFamily[S].Element[Self.Value] == A0 and ValidationFamily[S].Element[W0] == A1 and ValidationFamily[S].Element[W1] == A2 and _ErrorCompatible[_CommonError[S.Error, Never], Never]:
        """Combine 3 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[ValidationFamily[S], ValidationFamily[S].Pure[_ProductRun[ValidationFamily[S], Self.Value, W0, W1].Payload], ValidationFamily[S].Pure[R], _CommonError[S.Error, Never]](_NativeNary3[A0, A1, A2, R, Never, F, False, o](Pointer(to=function)), self.value^, others^))

    def par_map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, X: Movable & Deinitable, F: _RaisingNary3[A0, A1, A2, R, X], W0: Movable & Deinitable, W1: Movable & Deinitable, //, S: Semigroup = _ListErrors[Self.Value]](deinit self, var others: Tuple[W0, W1], ref[o] function: F) raises _CommonError[S.Error, X] -> Piped[ValidationFamily[S].Pure[R]] where Self.Value == ValidationFamily[S].Pure[ValidationFamily[S].Element[Self.Value]] and _ProductRun[ValidationFamily[S], Self.Value, W0, W1].NativeInputs and ValidationFamily[S].Element[Self.Value] == A0 and ValidationFamily[S].Element[W0] == A1 and ValidationFamily[S].Element[W1] == A2 and _ErrorCompatible[_CommonError[S.Error, X], X]:
        """Combine 3 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[ValidationFamily[S], ValidationFamily[S].Pure[_ProductRun[ValidationFamily[S], Self.Value, W0, W1].Payload], ValidationFamily[S].Pure[R], _CommonError[S.Error, X]](_NativeNary3[A0, A1, A2, R, X, F, True, o](Pointer(to=function)), self.value^, others^))

    def par_map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, F: _Nary4[A0, A1, A2, A3, R], W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, //, S: Semigroup = _ListErrors[Self.Value]](deinit self, var others: Tuple[W0, W1, W2], ref[o] function: F) raises _CommonError[S.Error, Never] -> Piped[ValidationFamily[S].Pure[R]] where Self.Value == ValidationFamily[S].Pure[ValidationFamily[S].Element[Self.Value]] and _ProductRun[ValidationFamily[S], Self.Value, W0, W1, W2].NativeInputs and ValidationFamily[S].Element[Self.Value] == A0 and ValidationFamily[S].Element[W0] == A1 and ValidationFamily[S].Element[W1] == A2 and ValidationFamily[S].Element[W2] == A3 and _ErrorCompatible[_CommonError[S.Error, Never], Never]:
        """Combine 4 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[ValidationFamily[S], ValidationFamily[S].Pure[_ProductRun[ValidationFamily[S], Self.Value, W0, W1, W2].Payload], ValidationFamily[S].Pure[R], _CommonError[S.Error, Never]](_NativeNary4[A0, A1, A2, A3, R, Never, F, False, o](Pointer(to=function)), self.value^, others^))

    def par_map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, X: Movable & Deinitable, F: _RaisingNary4[A0, A1, A2, A3, R, X], W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, //, S: Semigroup = _ListErrors[Self.Value]](deinit self, var others: Tuple[W0, W1, W2], ref[o] function: F) raises _CommonError[S.Error, X] -> Piped[ValidationFamily[S].Pure[R]] where Self.Value == ValidationFamily[S].Pure[ValidationFamily[S].Element[Self.Value]] and _ProductRun[ValidationFamily[S], Self.Value, W0, W1, W2].NativeInputs and ValidationFamily[S].Element[Self.Value] == A0 and ValidationFamily[S].Element[W0] == A1 and ValidationFamily[S].Element[W1] == A2 and ValidationFamily[S].Element[W2] == A3 and _ErrorCompatible[_CommonError[S.Error, X], X]:
        """Combine 4 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[ValidationFamily[S], ValidationFamily[S].Pure[_ProductRun[ValidationFamily[S], Self.Value, W0, W1, W2].Payload], ValidationFamily[S].Pure[R], _CommonError[S.Error, X]](_NativeNary4[A0, A1, A2, A3, R, X, F, True, o](Pointer(to=function)), self.value^, others^))

    def par_map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, F: _Nary5[A0, A1, A2, A3, A4, R], W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, W3: Movable & Deinitable, //, S: Semigroup = _ListErrors[Self.Value]](deinit self, var others: Tuple[W0, W1, W2, W3], ref[o] function: F) raises _CommonError[S.Error, Never] -> Piped[ValidationFamily[S].Pure[R]] where Self.Value == ValidationFamily[S].Pure[ValidationFamily[S].Element[Self.Value]] and _ProductRun[ValidationFamily[S], Self.Value, W0, W1, W2, W3].NativeInputs and ValidationFamily[S].Element[Self.Value] == A0 and ValidationFamily[S].Element[W0] == A1 and ValidationFamily[S].Element[W1] == A2 and ValidationFamily[S].Element[W2] == A3 and ValidationFamily[S].Element[W3] == A4 and _ErrorCompatible[_CommonError[S.Error, Never], Never]:
        """Combine 5 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[ValidationFamily[S], ValidationFamily[S].Pure[_ProductRun[ValidationFamily[S], Self.Value, W0, W1, W2, W3].Payload], ValidationFamily[S].Pure[R], _CommonError[S.Error, Never]](_NativeNary5[A0, A1, A2, A3, A4, R, Never, F, False, o](Pointer(to=function)), self.value^, others^))

    def par_map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, X: Movable & Deinitable, F: _RaisingNary5[A0, A1, A2, A3, A4, R, X], W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, W3: Movable & Deinitable, //, S: Semigroup = _ListErrors[Self.Value]](deinit self, var others: Tuple[W0, W1, W2, W3], ref[o] function: F) raises _CommonError[S.Error, X] -> Piped[ValidationFamily[S].Pure[R]] where Self.Value == ValidationFamily[S].Pure[ValidationFamily[S].Element[Self.Value]] and _ProductRun[ValidationFamily[S], Self.Value, W0, W1, W2, W3].NativeInputs and ValidationFamily[S].Element[Self.Value] == A0 and ValidationFamily[S].Element[W0] == A1 and ValidationFamily[S].Element[W1] == A2 and ValidationFamily[S].Element[W2] == A3 and ValidationFamily[S].Element[W3] == A4 and _ErrorCompatible[_CommonError[S.Error, X], X]:
        """Combine 5 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[ValidationFamily[S], ValidationFamily[S].Pure[_ProductRun[ValidationFamily[S], Self.Value, W0, W1, W2, W3].Payload], ValidationFamily[S].Pure[R], _CommonError[S.Error, X]](_NativeNary5[A0, A1, A2, A3, A4, R, X, F, True, o](Pointer(to=function)), self.value^, others^))

    def par_map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, F: _Nary6[A0, A1, A2, A3, A4, A5, R], W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, W3: Movable & Deinitable, W4: Movable & Deinitable, //, S: Semigroup = _ListErrors[Self.Value]](deinit self, var others: Tuple[W0, W1, W2, W3, W4], ref[o] function: F) raises _CommonError[S.Error, Never] -> Piped[ValidationFamily[S].Pure[R]] where Self.Value == ValidationFamily[S].Pure[ValidationFamily[S].Element[Self.Value]] and _ProductRun[ValidationFamily[S], Self.Value, W0, W1, W2, W3, W4].NativeInputs and ValidationFamily[S].Element[Self.Value] == A0 and ValidationFamily[S].Element[W0] == A1 and ValidationFamily[S].Element[W1] == A2 and ValidationFamily[S].Element[W2] == A3 and ValidationFamily[S].Element[W3] == A4 and ValidationFamily[S].Element[W4] == A5 and _ErrorCompatible[_CommonError[S.Error, Never], Never]:
        """Combine 6 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[ValidationFamily[S], ValidationFamily[S].Pure[_ProductRun[ValidationFamily[S], Self.Value, W0, W1, W2, W3, W4].Payload], ValidationFamily[S].Pure[R], _CommonError[S.Error, Never]](_NativeNary6[A0, A1, A2, A3, A4, A5, R, Never, F, False, o](Pointer(to=function)), self.value^, others^))

    def par_map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, X: Movable & Deinitable, F: _RaisingNary6[A0, A1, A2, A3, A4, A5, R, X], W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, W3: Movable & Deinitable, W4: Movable & Deinitable, //, S: Semigroup = _ListErrors[Self.Value]](deinit self, var others: Tuple[W0, W1, W2, W3, W4], ref[o] function: F) raises _CommonError[S.Error, X] -> Piped[ValidationFamily[S].Pure[R]] where Self.Value == ValidationFamily[S].Pure[ValidationFamily[S].Element[Self.Value]] and _ProductRun[ValidationFamily[S], Self.Value, W0, W1, W2, W3, W4].NativeInputs and ValidationFamily[S].Element[Self.Value] == A0 and ValidationFamily[S].Element[W0] == A1 and ValidationFamily[S].Element[W1] == A2 and ValidationFamily[S].Element[W2] == A3 and ValidationFamily[S].Element[W3] == A4 and ValidationFamily[S].Element[W4] == A5 and _ErrorCompatible[_CommonError[S.Error, X], X]:
        """Combine 6 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[ValidationFamily[S], ValidationFamily[S].Pure[_ProductRun[ValidationFamily[S], Self.Value, W0, W1, W2, W3, W4].Payload], ValidationFamily[S].Pure[R], _CommonError[S.Error, X]](_NativeNary6[A0, A1, A2, A3, A4, A5, R, X, F, True, o](Pointer(to=function)), self.value^, others^))

    def par_map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, F: _Nary7[A0, A1, A2, A3, A4, A5, A6, R], W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, W3: Movable & Deinitable, W4: Movable & Deinitable, W5: Movable & Deinitable, //, S: Semigroup = _ListErrors[Self.Value]](deinit self, var others: Tuple[W0, W1, W2, W3, W4, W5], ref[o] function: F) raises _CommonError[S.Error, Never] -> Piped[ValidationFamily[S].Pure[R]] where Self.Value == ValidationFamily[S].Pure[ValidationFamily[S].Element[Self.Value]] and _ProductRun[ValidationFamily[S], Self.Value, W0, W1, W2, W3, W4, W5].NativeInputs and ValidationFamily[S].Element[Self.Value] == A0 and ValidationFamily[S].Element[W0] == A1 and ValidationFamily[S].Element[W1] == A2 and ValidationFamily[S].Element[W2] == A3 and ValidationFamily[S].Element[W3] == A4 and ValidationFamily[S].Element[W4] == A5 and ValidationFamily[S].Element[W5] == A6 and _ErrorCompatible[_CommonError[S.Error, Never], Never]:
        """Combine 7 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[ValidationFamily[S], ValidationFamily[S].Pure[_ProductRun[ValidationFamily[S], Self.Value, W0, W1, W2, W3, W4, W5].Payload], ValidationFamily[S].Pure[R], _CommonError[S.Error, Never]](_NativeNary7[A0, A1, A2, A3, A4, A5, A6, R, Never, F, False, o](Pointer(to=function)), self.value^, others^))

    def par_map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, X: Movable & Deinitable, F: _RaisingNary7[A0, A1, A2, A3, A4, A5, A6, R, X], W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, W3: Movable & Deinitable, W4: Movable & Deinitable, W5: Movable & Deinitable, //, S: Semigroup = _ListErrors[Self.Value]](deinit self, var others: Tuple[W0, W1, W2, W3, W4, W5], ref[o] function: F) raises _CommonError[S.Error, X] -> Piped[ValidationFamily[S].Pure[R]] where Self.Value == ValidationFamily[S].Pure[ValidationFamily[S].Element[Self.Value]] and _ProductRun[ValidationFamily[S], Self.Value, W0, W1, W2, W3, W4, W5].NativeInputs and ValidationFamily[S].Element[Self.Value] == A0 and ValidationFamily[S].Element[W0] == A1 and ValidationFamily[S].Element[W1] == A2 and ValidationFamily[S].Element[W2] == A3 and ValidationFamily[S].Element[W3] == A4 and ValidationFamily[S].Element[W4] == A5 and ValidationFamily[S].Element[W5] == A6 and _ErrorCompatible[_CommonError[S.Error, X], X]:
        """Combine 7 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[ValidationFamily[S], ValidationFamily[S].Pure[_ProductRun[ValidationFamily[S], Self.Value, W0, W1, W2, W3, W4, W5].Payload], ValidationFamily[S].Pure[R], _CommonError[S.Error, X]](_NativeNary7[A0, A1, A2, A3, A4, A5, A6, R, X, F, True, o](Pointer(to=function)), self.value^, others^))

    def par_map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, F: _Nary8[A0, A1, A2, A3, A4, A5, A6, A7, R], W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, W3: Movable & Deinitable, W4: Movable & Deinitable, W5: Movable & Deinitable, W6: Movable & Deinitable, //, S: Semigroup = _ListErrors[Self.Value]](deinit self, var others: Tuple[W0, W1, W2, W3, W4, W5, W6], ref[o] function: F) raises _CommonError[S.Error, Never] -> Piped[ValidationFamily[S].Pure[R]] where Self.Value == ValidationFamily[S].Pure[ValidationFamily[S].Element[Self.Value]] and _ProductRun[ValidationFamily[S], Self.Value, W0, W1, W2, W3, W4, W5, W6].NativeInputs and ValidationFamily[S].Element[Self.Value] == A0 and ValidationFamily[S].Element[W0] == A1 and ValidationFamily[S].Element[W1] == A2 and ValidationFamily[S].Element[W2] == A3 and ValidationFamily[S].Element[W3] == A4 and ValidationFamily[S].Element[W4] == A5 and ValidationFamily[S].Element[W5] == A6 and ValidationFamily[S].Element[W6] == A7 and _ErrorCompatible[_CommonError[S.Error, Never], Never]:
        """Combine 8 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[ValidationFamily[S], ValidationFamily[S].Pure[_ProductRun[ValidationFamily[S], Self.Value, W0, W1, W2, W3, W4, W5, W6].Payload], ValidationFamily[S].Pure[R], _CommonError[S.Error, Never]](_NativeNary8[A0, A1, A2, A3, A4, A5, A6, A7, R, Never, F, False, o](Pointer(to=function)), self.value^, others^))

    def par_map_n[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, X: Movable & Deinitable, F: _RaisingNary8[A0, A1, A2, A3, A4, A5, A6, A7, R, X], W0: Movable & Deinitable, W1: Movable & Deinitable, W2: Movable & Deinitable, W3: Movable & Deinitable, W4: Movable & Deinitable, W5: Movable & Deinitable, W6: Movable & Deinitable, //, S: Semigroup = _ListErrors[Self.Value]](deinit self, var others: Tuple[W0, W1, W2, W3, W4, W5, W6], ref[o] function: F) raises _CommonError[S.Error, X] -> Piped[ValidationFamily[S].Pure[R]] where Self.Value == ValidationFamily[S].Pure[ValidationFamily[S].Element[Self.Value]] and _ProductRun[ValidationFamily[S], Self.Value, W0, W1, W2, W3, W4, W5, W6].NativeInputs and ValidationFamily[S].Element[Self.Value] == A0 and ValidationFamily[S].Element[W0] == A1 and ValidationFamily[S].Element[W1] == A2 and ValidationFamily[S].Element[W2] == A3 and ValidationFamily[S].Element[W3] == A4 and ValidationFamily[S].Element[W4] == A5 and ValidationFamily[S].Element[W5] == A6 and ValidationFamily[S].Element[W6] == A7 and _ErrorCompatible[_CommonError[S.Error, X], X]:
        """Combine 8 operands and call the native callback with separate arguments."""
        return Piped(_map_n_as[ValidationFamily[S], ValidationFamily[S].Pure[_ProductRun[ValidationFamily[S], Self.Value, W0, W1, W2, W3, W4, W5, W6].Payload], ValidationFamily[S].Pure[R], _CommonError[S.Error, X]](_NativeNary8[A0, A1, A2, A3, A4, A5, A6, A7, R, X, F, True, o](Pointer(to=function)), self.value^, others^))

    def map2[F: BinaryContract & Movable & Deinitable, W: Movable & Deinitable, //](deinit self, var other: W, var function: F) raises F.Error -> Piped[List[F.Out]] where Self.Value == List[F.First] and _CombineCompatible[ListFamily, List[F.First], F, _ValueThunk[List[F.Second]]] and W == List[F.Second]:
        """Combine two already evaluated carriers, following their Applicative semantics.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            W: The second carrier type, including its origins.

        Args:
            other: The already evaluated second carrier, consumed. Constructing it is not deferred by this call.
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The combined carrier; Result keeps the first stored error, Optional requires both values, and List produces a Cartesian product in left-major order.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_map2_as[ListFamily, X=F.Error](function^, rebind_var[List[F.First]](self.value^), rebind_var[List[F.Second]](other^)))

    def map2[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W: Movable & Deinitable, //, F: _Binary[A, B, R]](deinit self, var other: W, ref[o] function: F) raises Never -> Piped[List[R]] where Self.Value == List[A] and _CombineCompatible[ListFamily, List[A], _NativeBinaryRef[A, B, R, Never, F, False, o], _ValueThunk[List[B]]] and W == List[B]:
        """Combine two already evaluated carriers, following their Applicative semantics."""
        return Piped(_map2_as[ListFamily, X=Never](_NativeBinaryRef[A, B, R, Never, F, False, o](Pointer(to=function)), rebind_var[List[A]](self.value^), rebind_var[List[B]](other^)))

    def map2[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W: Movable & Deinitable, //, X: Movable & Deinitable, F: _RaisingBinary[A, B, R, X]](deinit self, var other: W, ref[o] function: F) raises X -> Piped[List[R]] where Self.Value == List[A] and _CombineCompatible[ListFamily, List[A], _NativeBinaryRef[A, B, R, X, F, True, o], _ValueThunk[List[B]]] and W == List[B]:
        """Combine two already evaluated carriers, following their Applicative semantics."""
        return Piped(_map2_as[ListFamily, X=X](_NativeBinaryRef[A, B, R, X, F, True, o](Pointer(to=function)), rebind_var[List[A]](self.value^), rebind_var[List[B]](other^)))

    def product[T: Movable & Deinitable, U: Movable & Deinitable](deinit self, var other: List[U]) -> Piped[List[Tuple[T, U]]] where Self.Value == List[T] and _CombineCompatible[ListFamily, List[T], _Pair[ListFamily.Element[List[T]], ListFamily.Element[List[U]]], _ValueThunk[List[U]]]:
        """Combine two already evaluated carriers into pairs, following their Applicative semantics.

        Parameters:
            T: The element type, including its native origins.
            U: The constant or result payload type; repeated constants must be Copyable.

        Args:
            other: The already evaluated second carrier, consumed. Constructing it is not deferred by this call.

        Returns:
            The carrier of pairs. List copies elements for its Cartesian product; Result and Optional move their payloads without copying.
        """
        return Piped(_map2_as[ListFamily, X=Never](_Pair[ListFamily.Element[List[T]], ListFamily.Element[List[U]]](), rebind_var[List[T]](self.value^), other^))

    def ap[A: Movable & Deinitable](deinit self, var values: List[A]) raises downcast[ListFamily.Element[Self.Value], UnaryContract & Movable & Deinitable].Error -> Piped[List[downcast[ListFamily.Element[Self.Value], UnaryContract & Movable & Deinitable].Out]] where conforms_to(ListFamily.Element[Self.Value], UnaryContract) and Self.Value == List[downcast[ListFamily.Element[Self.Value], UnaryContract & Movable & Deinitable]] and A == downcast[ListFamily.Element[Self.Value], UnaryContract & Movable & Deinitable].Arg and _CombineCompatible[ListFamily, List[downcast[ListFamily.Element[Self.Value], UnaryContract & Movable & Deinitable]], _Apply[downcast[ListFamily.Element[Self.Value], UnaryContract & Movable & Deinitable]], _ValueThunk[List[downcast[ListFamily.Element[Self.Value], UnaryContract & Movable & Deinitable].Arg]]]:
        """Apply the callbacks in this carrier to an already evaluated carrier of arguments.

        Parameters:
            A: The callback input type, including its native origins.

        Args:
            values: The already evaluated carrier of callback arguments, consumed.

        Returns:
            The carrier of callback results. List applies each callback to each value in function-major order; Optional and Result invoke at most once.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_map2_as[ListFamily, X=downcast[ListFamily.Element[Self.Value], UnaryContract & Movable & Deinitable].Error](_Apply[downcast[ListFamily.Element[Self.Value], UnaryContract & Movable & Deinitable]](), rebind_var[List[downcast[ListFamily.Element[Self.Value], UnaryContract & Movable & Deinitable]]](self.value^), rebind_var[List[downcast[ListFamily.Element[Self.Value], UnaryContract & Movable & Deinitable].Arg]](values^)))

    def map2[F: BinaryContract & Movable & Deinitable, W: Movable & Deinitable, //](deinit self, var other: W, var function: F) raises F.Error -> Piped[Optional[F.Out]] where Self.Value == Optional[F.First] and W == Optional[F.Second]:
        """Combine two already evaluated carriers, following their Applicative semantics.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            W: The second carrier type, including its origins.

        Args:
            other: The already evaluated second carrier, consumed. Constructing it is not deferred by this call.
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The combined carrier; Result keeps the first stored error, Optional requires both values, and List produces a Cartesian product in left-major order.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_map2_as[OptionalFamily, X=F.Error](function^, rebind_var[Optional[F.First]](self.value^), rebind_var[Optional[F.Second]](other^)))

    def map2[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W: Movable & Deinitable, //, F: _Binary[A, B, R]](deinit self, var other: W, ref[o] function: F) raises Never -> Piped[Optional[R]] where Self.Value == Optional[A] and W == Optional[B]:
        """Combine two already evaluated carriers, following their Applicative semantics."""
        return Piped(_map2_as[OptionalFamily, X=Never](_NativeBinaryRef[A, B, R, Never, F, False, o](Pointer(to=function)), rebind_var[Optional[A]](self.value^), rebind_var[Optional[B]](other^)))

    def map2[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W: Movable & Deinitable, //, X: Movable & Deinitable, F: _RaisingBinary[A, B, R, X]](deinit self, var other: W, ref[o] function: F) raises X -> Piped[Optional[R]] where Self.Value == Optional[A] and W == Optional[B]:
        """Combine two already evaluated carriers, following their Applicative semantics."""
        return Piped(_map2_as[OptionalFamily, X=X](_NativeBinaryRef[A, B, R, X, F, True, o](Pointer(to=function)), rebind_var[Optional[A]](self.value^), rebind_var[Optional[B]](other^)))

    def product[T: Movable & Deinitable, U: Movable & Deinitable](deinit self, var other: Optional[U]) -> Piped[Optional[Tuple[T, U]]] where Self.Value == Optional[T]:
        """Combine two already evaluated carriers into pairs, following their Applicative semantics.

        Parameters:
            T: The element type, including its native origins.
            U: The constant or result payload type; repeated constants must be Copyable.

        Args:
            other: The already evaluated second carrier, consumed. Constructing it is not deferred by this call.

        Returns:
            The carrier of pairs. List copies elements for its Cartesian product; Result and Optional move their payloads without copying.
        """
        return Piped(_family_product[OptionalFamily](rebind_var[Optional[T]](self.value^), other^))

    def ap[A: Movable & Deinitable](deinit self, var values: Optional[A]) raises downcast[OptionalFamily.Element[Self.Value], UnaryContract & Movable & Deinitable].Error -> Piped[Optional[downcast[OptionalFamily.Element[Self.Value], UnaryContract & Movable & Deinitable].Out]] where conforms_to(OptionalFamily.Element[Self.Value], UnaryContract) and Self.Value == Optional[downcast[OptionalFamily.Element[Self.Value], UnaryContract & Movable & Deinitable]] and A == downcast[OptionalFamily.Element[Self.Value], UnaryContract & Movable & Deinitable].Arg:
        """Apply the callbacks in this carrier to an already evaluated carrier of arguments.

        Parameters:
            A: The callback input type, including its native origins.

        Args:
            values: The already evaluated carrier of callback arguments, consumed.

        Returns:
            The carrier of callback results. List applies each callback to each value in function-major order; Optional and Result invoke at most once.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_map2_as[OptionalFamily, X=downcast[OptionalFamily.Element[Self.Value], UnaryContract & Movable & Deinitable].Error](_Apply[downcast[OptionalFamily.Element[Self.Value], UnaryContract & Movable & Deinitable]](), rebind_var[Optional[downcast[OptionalFamily.Element[Self.Value], UnaryContract & Movable & Deinitable]]](self.value^), rebind_var[Optional[downcast[OptionalFamily.Element[Self.Value], UnaryContract & Movable & Deinitable].Arg]](values^)))

    def map2[F: BinaryContract & Movable & Deinitable, W: Movable & Deinitable, Failure: Movable & Deinitable, //](deinit self, var other: W, var function: F) raises F.Error -> Piped[Result[F.Out, Failure]] where Self.Value == Result[F.First, Failure] and W == Result[F.Second, Failure]:
        """Combine two already evaluated carriers, following their Applicative semantics.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            W: The second carrier type, including its origins.
            Failure: The error payload type retained by Result.

        Args:
            other: The already evaluated second carrier, consumed. Constructing it is not deferred by this call.
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The combined carrier; Result keeps the first stored error, Optional requires both values, and List produces a Cartesian product in left-major order.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_map2_as[ResultFamily[Failure], X=F.Error](function^, rebind_var[Result[F.First, Failure]](self.value^), rebind_var[Result[F.Second, Failure]](other^)))

    def map2[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W: Movable & Deinitable, Failure: Movable & Deinitable, //, F: _Binary[A, B, R]](deinit self, var other: W, ref[o] function: F) raises Never -> Piped[Result[R, Failure]] where Self.Value == Result[A, Failure] and W == Result[B, Failure]:
        """Combine two already evaluated carriers, following their Applicative semantics."""
        return Piped(_map2_as[ResultFamily[Failure], X=Never](_NativeBinaryRef[A, B, R, Never, F, False, o](Pointer(to=function)), rebind_var[Result[A, Failure]](self.value^), rebind_var[Result[B, Failure]](other^)))

    def map2[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, W: Movable & Deinitable, Failure: Movable & Deinitable, //, X: Movable & Deinitable, F: _RaisingBinary[A, B, R, X]](deinit self, var other: W, ref[o] function: F) raises X -> Piped[Result[R, Failure]] where Self.Value == Result[A, Failure] and W == Result[B, Failure]:
        """Combine two already evaluated carriers, following their Applicative semantics."""
        return Piped(_map2_as[ResultFamily[Failure], X=X](_NativeBinaryRef[A, B, R, X, F, True, o](Pointer(to=function)), rebind_var[Result[A, Failure]](self.value^), rebind_var[Result[B, Failure]](other^)))

    def product[T: Movable & Deinitable, U: Movable & Deinitable, Failure: Movable & Deinitable](deinit self, var other: Result[U, Failure]) -> Piped[Result[Tuple[T, U], Failure]] where Self.Value == Result[T, Failure]:
        """Combine two already evaluated carriers into pairs, following their Applicative semantics.

        Parameters:
            T: The element type, including its native origins.
            U: The constant or result payload type; repeated constants must be Copyable.
            Failure: The error payload type retained by Result.

        Args:
            other: The already evaluated second carrier, consumed. Constructing it is not deferred by this call.

        Returns:
            The carrier of pairs. List copies elements for its Cartesian product; Result and Optional move their payloads without copying.
        """
        return Piped(_family_product[ResultFamily[Failure]](rebind_var[Result[T, Failure]](self.value^), other^))

    def ap[A: Movable & Deinitable, Failure: Movable & Deinitable](deinit self, var values: Result[A, Failure]) raises downcast[ResultFamily[Failure].Element[Self.Value], UnaryContract & Movable & Deinitable].Error -> Piped[Result[downcast[ResultFamily[Failure].Element[Self.Value], UnaryContract & Movable & Deinitable].Out, Failure]] where conforms_to(ResultFamily[Failure].Element[Self.Value], UnaryContract) and Self.Value == Result[downcast[ResultFamily[Failure].Element[Self.Value], UnaryContract & Movable & Deinitable], Failure] and A == downcast[ResultFamily[Failure].Element[Self.Value], UnaryContract & Movable & Deinitable].Arg:
        """Apply the callbacks in this carrier to an already evaluated carrier of arguments.

        Parameters:
            A: The callback input type, including its native origins.
            Failure: The error payload type retained by Result.

        Args:
            values: The already evaluated carrier of callback arguments, consumed.

        Returns:
            The carrier of callback results. List applies each callback to each value in function-major order; Optional and Result invoke at most once.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_map2_as[ResultFamily[Failure], X=downcast[ResultFamily[Failure].Element[Self.Value], UnaryContract & Movable & Deinitable].Error](_Apply[downcast[ResultFamily[Failure].Element[Self.Value], UnaryContract & Movable & Deinitable]](), rebind_var[Result[downcast[ResultFamily[Failure].Element[Self.Value], UnaryContract & Movable & Deinitable], Failure]](self.value^), rebind_var[Result[downcast[ResultFamily[Failure].Element[Self.Value], UnaryContract & Movable & Deinitable].Arg, Failure]](values^)))

    def fill[T: Movable & Deinitable, U: Movable & Deinitable](deinit self, var value: U) -> Piped[List[U]] where Self.Value == List[T] and _MapCompatible[ListFamily, List[T], _Fill[T, U]]:
        """Replace payloads with value, moving it for a single call or copying for repeated calls."""
        comptime assert Self.Value == List[T]
        return Piped(ListFamily.map(_Fill[T, U](value^), rebind_var[List[T]](self.value^)))

    def replace[T: Copyable & Equatable & Deinitable](deinit self, var old: T, var new: T) -> Piped[List[T]] where Self.Value == List[T]:
        """Replace equal payloads, moving unmatched values unchanged."""
        comptime assert Self.Value == List[T]
        return Piped(ListFamily.map(_Replace[T](old^, new^), rebind_var[List[T]](self.value^)))

    def void[T: Movable & Deinitable](deinit self) -> Piped[List[NoneType]] where Self.Value == List[T]:
        """Discard payloads while preserving their container shape."""
        comptime assert Self.Value == List[T]
        return Piped(ListFamily.map(_Fill[T, NoneType](None), rebind_var[List[T]](self.value^)))

    def tuple_left[T: Movable & Deinitable, U: Movable & Deinitable](deinit self, var value: U) -> Piped[List[Tuple[U, T]]] where Self.Value == List[T] and _MapCompatible[ListFamily, List[T], _TupleWith[T, U, True]]:
        """Attach value on the left, moving it for a single call or copying for repeated calls."""
        comptime assert Self.Value == List[T]
        return Piped(ListFamily.map(_TupleWith[T, U, True](value^), rebind_var[List[T]](self.value^)))

    def tuple_right[T: Movable & Deinitable, U: Movable & Deinitable](deinit self, var value: U) -> Piped[List[Tuple[T, U]]] where Self.Value == List[T] and _MapCompatible[ListFamily, List[T], _TupleWith[T, U, False]]:
        """Attach value on the right, moving it for a single call or copying for repeated calls."""
        comptime assert Self.Value == List[T]
        return Piped(ListFamily.map(_TupleWith[T, U, False](value^), rebind_var[List[T]](self.value^)))

    def pair_with[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[List[Tuple[downcast[P, Movable & Deinitable], R]]] where Self.Value == List[downcast[P, Movable & Deinitable]]:
        """Borrow each payload for projection and retain it beside the result."""
        comptime assert Self.Value == List[downcast[P, Movable & Deinitable]]
        return Piped(ListFamily.map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[List[downcast[P, Movable & Deinitable]]](self.value^)))

    def pair_with[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[List[Tuple[downcast[P, Movable & Deinitable], R]]] where Self.Value == List[downcast[P, Movable & Deinitable]]:
        """Borrow each payload for projection and retain it beside the result."""
        comptime assert Self.Value == List[downcast[P, Movable & Deinitable]]
        return Piped(ListFamily.map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[List[downcast[P, Movable & Deinitable]]](self.value^)))

    def pair_with[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](deinit self, var function: C) raises C.Failure -> Piped[List[Tuple[T, C.Result]]] where Self.Value == List[T] and C.Payload == T and RepeatableBorrow[C]:
        """Borrow each payload for projection and retain it beside the result."""
        comptime assert Self.Value == List[T]
        return Piped(ListFamily.map(_Observe[T, C, True](function^), rebind_var[List[T]](self.value^)))

    def tap_each[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[List[downcast[P, Movable & Deinitable]]] where Self.Value == List[downcast[P, Movable & Deinitable]]:
        """Borrow each payload for inspection and retain it unchanged."""
        comptime assert Self.Value == List[downcast[P, Movable & Deinitable]]
        return Piped(ListFamily.map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], False](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[List[downcast[P, Movable & Deinitable]]](self.value^)))

    def tap_each[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[List[downcast[P, Movable & Deinitable]]] where Self.Value == List[downcast[P, Movable & Deinitable]]:
        """Borrow each payload for inspection and retain it unchanged."""
        comptime assert Self.Value == List[downcast[P, Movable & Deinitable]]
        return Piped(ListFamily.map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], False](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[List[downcast[P, Movable & Deinitable]]](self.value^)))

    def tap_each[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](deinit self, var function: C) raises C.Failure -> Piped[List[T]] where Self.Value == List[T] and C.Payload == T and RepeatableBorrow[C]:
        """Borrow each payload for inspection and retain it unchanged."""
        comptime assert Self.Value == List[T]
        return Piped(ListFamily.map(_Observe[T, C, False](function^), rebind_var[List[T]](self.value^)))

    def filter_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises ListFamily.MapFilterError[List[A], _NativeUnaryRef[A, R, Never, F, False, o]] -> Piped[ListFamily.MapFiltered[List[A], _NativeUnaryRef[A, R, Never, F, False, o]]] where Self.Value == List[A]:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        comptime assert Self.Value == List[A]
        return Piped(ListFamily.filter_map(_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), rebind_var[List[A]](self.value^)))

    def filter_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises ListFamily.MapFilterError[List[A], _NativeUnaryRef[A, R, E, F, True, o]] -> Piped[ListFamily.MapFiltered[List[A], _NativeUnaryRef[A, R, E, F, True, o]]] where Self.Value == List[A]:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        comptime assert Self.Value == List[A]
        return Piped(ListFamily.filter_map(_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), rebind_var[List[A]](self.value^)))

    def filter_map[F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises ListFamily.MapFilterError[List[F.Arg], F] -> Piped[ListFamily.MapFiltered[List[F.Arg], F]] where Self.Value == List[F.Arg]:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        comptime assert Self.Value == List[F.Arg]
        return Piped(ListFamily.filter_map(function^, rebind_var[List[F.Arg]](self.value^)))

    def filter_map[F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises ListFamily.MapFilterError[List[F._View[o].Arg], F._View[o]] -> Piped[ListFamily.MapFiltered[List[F._View[o].Arg], F._View[o]]] where Self.Value == List[F._View[o].Arg]:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        comptime assert Self.Value == List[F._View[o].Arg]
        return Piped(ListFamily.filter_map(function._unary_view(), rebind_var[List[F._View[o].Arg]](self.value^)))

    def flat_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises ListFamily.BindError[List[A], _NativeUnaryRef[A, R, Never, F, False, o]] -> Piped[ListFamily.Bound[List[A], _NativeUnaryRef[A, R, Never, F, False, o]]] where Self.Value == List[A]:
        """Apply flat_map through the carrier's Monad capability."""
        comptime assert Self.Value == List[A]
        return Piped(ListFamily.flat_map(_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), rebind_var[List[A]](self.value^)))

    def flat_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises ListFamily.BindError[List[A], _NativeUnaryRef[A, R, E, F, True, o]] -> Piped[ListFamily.Bound[List[A], _NativeUnaryRef[A, R, E, F, True, o]]] where Self.Value == List[A]:
        """Apply flat_map through the carrier's Monad capability."""
        comptime assert Self.Value == List[A]
        return Piped(ListFamily.flat_map(_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), rebind_var[List[A]](self.value^)))

    def flat_map[F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises ListFamily.BindError[List[F.Arg], F] -> Piped[ListFamily.Bound[List[F.Arg], F]] where Self.Value == List[F.Arg]:
        """Apply flat_map through the carrier's Monad capability."""
        comptime assert Self.Value == List[F.Arg]
        return Piped(ListFamily.flat_map(function^, rebind_var[List[F.Arg]](self.value^)))

    def flat_map[F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises ListFamily.BindError[List[F._View[o].Arg], F._View[o]] -> Piped[ListFamily.Bound[List[F._View[o].Arg], F._View[o]]] where Self.Value == List[F._View[o].Arg]:
        """Apply flat_map through the carrier's Monad capability."""
        comptime assert Self.Value == List[F._View[o].Arg]
        return Piped(ListFamily.flat_map(function._unary_view(), rebind_var[List[F._View[o].Arg]](self.value^)))

    def traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, F: _Unary[A, R]](deinit self, ref[o] function: F) raises ListFamily.TraverseError[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]] -> Piped[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]]] where Self.Value == List[A] and ListFamily.TargetCompatible[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]]:
        """Apply traverse through the carrier's Traversable capability."""
        comptime assert Self.Value == List[A]
        return Piped(ListFamily.traverse[G](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), rebind_var[List[A]](self.value^)))

    def traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises ListFamily.TraverseError[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]] -> Piped[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]]] where Self.Value == List[A] and ListFamily.TargetCompatible[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]]:
        """Apply traverse through the carrier's Traversable capability."""
        comptime assert Self.Value == List[A]
        return Piped(ListFamily.traverse[G](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), rebind_var[List[A]](self.value^)))

    def traverse[F: UnaryContract & Movable & Deinitable, //, G: Applicative](deinit self, var function: F) raises ListFamily.TraverseError[G, List[F.Arg], F] -> Piped[ListFamily.Traversed[G, List[F.Arg], F]] where Self.Value == List[F.Arg] and ListFamily.TargetCompatible[G, List[F.Arg], F]:
        """Apply traverse through the carrier's Traversable capability."""
        comptime assert Self.Value == List[F.Arg]
        return Piped(ListFamily.traverse[G](function^, rebind_var[List[F.Arg]](self.value^)))

    def traverse[F: _UnaryViewable, o: ImmOrigin, //, G: Applicative](deinit self, ref[o] function: F) raises ListFamily.TraverseError[G, List[F._View[o].Arg], F._View[o]] -> Piped[ListFamily.Traversed[G, List[F._View[o].Arg], F._View[o]]] where Self.Value == List[F._View[o].Arg] and ListFamily.TargetCompatible[G, List[F._View[o].Arg], F._View[o]]:
        """Apply traverse through the carrier's Traversable capability."""
        comptime assert Self.Value == List[F._View[o].Arg]
        return Piped(ListFamily.traverse[G](function._unary_view(), rebind_var[List[F._View[o].Arg]](self.value^)))

    def par_traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, F: _Unary[A, R], //, S: Semigroup = _ListErrors[R]](deinit self, ref[o] function: F) raises ListFamily.TraverseError[ValidationFamily[S], List[A], _NativeUnaryRef[A, R, Never, F, False, o]] -> Piped[ListFamily.Traversed[ValidationFamily[S], List[A], _NativeUnaryRef[A, R, Never, F, False, o]]] where Self.Value == List[A] and ListFamily.TargetCompatible[ValidationFamily[S], List[A], _NativeUnaryRef[A, R, Never, F, False, o]] and _CarrierCompatible[ValidationFamily[S], R]:
        """Apply par_traverse through the carrier's Traversable capability.

        Parameters:
            A: The callback input type, including its native origins.
            R: The native callback result type.
            o: The origin of the borrowed native callback.
            F: The callback type, retaining its receiver, captures and error contract.
            S: The error Semigroup; defaults to concatenation of list-valued stored errors.

        Args:
            function: The callback, borrowed in place; calls follow the operation's evaluation order.

        Returns:
            A Result containing the transformed source shape (List for Iter), or stored errors accumulated in source order. Every finite input is visited unless a native error is raised.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        comptime assert Self.Value == List[A]
        return Piped(ListFamily.traverse[ValidationFamily[S]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), rebind_var[List[A]](self.value^)))

    def par_traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], //, S: Semigroup = _ListErrors[R]](deinit self, ref[o] function: F) raises ListFamily.TraverseError[ValidationFamily[S], List[A], _NativeUnaryRef[A, R, E, F, True, o]] -> Piped[ListFamily.Traversed[ValidationFamily[S], List[A], _NativeUnaryRef[A, R, E, F, True, o]]] where Self.Value == List[A] and ListFamily.TargetCompatible[ValidationFamily[S], List[A], _NativeUnaryRef[A, R, E, F, True, o]] and _CarrierCompatible[ValidationFamily[S], R]:
        """Apply par_traverse through the carrier's Traversable capability."""
        comptime assert Self.Value == List[A]
        return Piped(ListFamily.traverse[ValidationFamily[S]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), rebind_var[List[A]](self.value^)))

    def par_traverse[F: UnaryContract & Movable & Deinitable, //, S: Semigroup = _ListErrors[F.Out]](deinit self, var function: F) raises ListFamily.TraverseError[ValidationFamily[S], List[F.Arg], F] -> Piped[ListFamily.Traversed[ValidationFamily[S], List[F.Arg], F]] where Self.Value == List[F.Arg] and ListFamily.TargetCompatible[ValidationFamily[S], List[F.Arg], F] and _CarrierCompatible[ValidationFamily[S], F.Out]:
        """Apply par_traverse through the carrier's Traversable capability."""
        comptime assert Self.Value == List[F.Arg]
        return Piped(ListFamily.traverse[ValidationFamily[S]](function^, rebind_var[List[F.Arg]](self.value^)))

    def par_traverse[F: _UnaryViewable, o: ImmOrigin, //, S: Semigroup = _ListErrors[F._View[o].Out]](deinit self, ref[o] function: F) raises ListFamily.TraverseError[ValidationFamily[S], List[F._View[o].Arg], F._View[o]] -> Piped[ListFamily.Traversed[ValidationFamily[S], List[F._View[o].Arg], F._View[o]]] where Self.Value == List[F._View[o].Arg] and ListFamily.TargetCompatible[ValidationFamily[S], List[F._View[o].Arg], F._View[o]] and _CarrierCompatible[ValidationFamily[S], F._View[o].Out]:
        """Apply par_traverse through the carrier's Traversable capability."""
        comptime assert Self.Value == List[F._View[o].Arg]
        return Piped(ListFamily.traverse[ValidationFamily[S]](function._unary_view(), rebind_var[List[F._View[o].Arg]](self.value^)))

    def compact[T: Movable & Deinitable, //](deinit self) raises ListFamily.MapFilterError[List[Optional[T]], _Same[Optional[T]]] -> Piped[ListFamily.MapFiltered[List[Optional[T]], _Same[Optional[T]]]] where Self.Value == List[Optional[T]]:
        """Derive compact through filter_map, preserving the family's semantics."""
        comptime assert Self.Value == List[Optional[T]]
        return Piped(ListFamily.filter_map(_Same[Optional[T]](), rebind_var[List[Optional[T]]](self.value^)))

    def flatten[T: Movable & Deinitable, //](deinit self) raises ListFamily.BindError[List[List[T]], _Same[List[T]]] -> Piped[ListFamily.Bound[List[List[T]], _Same[List[T]]]] where Self.Value == List[List[T]]:
        """Derive flatten through flat_map, preserving the family's semantics."""
        comptime assert Self.Value == List[List[T]]
        return Piped(ListFamily.flat_map(_Same[List[T]](), rebind_var[List[List[T]]](self.value^)))

    def sequence[T: Movable & Deinitable, //, G: Applicative](deinit self) raises ListFamily.TraverseError[G, List[T], _Same[T]] -> Piped[ListFamily.Traversed[G, List[T], _Same[T]]] where Self.Value == List[T] and ListFamily.TargetCompatible[G, List[T], _Same[T]]:
        """Derive sequence through traverse, preserving the family's semantics."""
        comptime assert Self.Value == List[T]
        return Piped(ListFamily.traverse[G](_Same[T](), rebind_var[List[T]](self.value^)))

    def par_sequence[T: Movable & Deinitable, //, S: Semigroup = _ListErrors[T]](deinit self) raises S.Error -> Piped[ListFamily.Traversed[ValidationFamily[S], List[T], _Same[T]]] where Self.Value == List[T] and ListFamily.TargetCompatible[ValidationFamily[S], List[T], _Same[T]] and _CarrierCompatible[ValidationFamily[S], T]:
        """Derive par_sequence through traverse, preserving the family's semantics.

        Parameters:
            T: The element type, including its native origins.
            S: The error Semigroup; defaults to concatenation of list-valued stored errors.

        Returns:
            A Result containing unwrapped payloads in source shape (List for Iter), or stored errors accumulated in source order. An empty source succeeds; a source Result error stays inside the target Result.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        comptime assert Self.Value == List[T]
        return Piped(_traverse_as[ListFamily, ValidationFamily[S], List[T], _Same[T], S.Error](_Same[T](), rebind_var[List[T]](self.value^)))

    def fill[T: Movable & Deinitable, U: Movable & Deinitable, N: Int](deinit self, var value: U) -> Piped[Array[U, N]] where Self.Value == Array[T, N] and _MapCompatible[_ArrayFamily[N], Array[T, N], _Fill[T, U]]:
        """Replace payloads with value, moving it for a single call or copying for repeated calls."""
        comptime assert Self.Value == Array[T, N]
        return Piped(_ArrayFamily[N].map(_Fill[T, U](value^), rebind_var[Array[T, N]](self.value^)))

    def replace[T: Copyable & Equatable & Deinitable, N: Int](deinit self, var old: T, var new: T) -> Piped[Array[T, N]] where Self.Value == Array[T, N]:
        """Replace equal payloads, moving unmatched values unchanged."""
        comptime assert Self.Value == Array[T, N]
        return Piped(_ArrayFamily[N].map(_Replace[T](old^, new^), rebind_var[Array[T, N]](self.value^)))

    def void[T: Movable & Deinitable, N: Int](deinit self) -> Piped[Array[NoneType, N]] where Self.Value == Array[T, N]:
        """Discard payloads while preserving their container shape."""
        comptime assert Self.Value == Array[T, N]
        return Piped(_ArrayFamily[N].map(_Fill[T, NoneType](None), rebind_var[Array[T, N]](self.value^)))

    def tuple_left[T: Movable & Deinitable, U: Movable & Deinitable, N: Int](deinit self, var value: U) -> Piped[Array[Tuple[U, T], N]] where Self.Value == Array[T, N] and _MapCompatible[_ArrayFamily[N], Array[T, N], _TupleWith[T, U, True]]:
        """Attach value on the left, moving it for a single call or copying for repeated calls."""
        comptime assert Self.Value == Array[T, N]
        return Piped(_ArrayFamily[N].map(_TupleWith[T, U, True](value^), rebind_var[Array[T, N]](self.value^)))

    def tuple_right[T: Movable & Deinitable, U: Movable & Deinitable, N: Int](deinit self, var value: U) -> Piped[Array[Tuple[T, U], N]] where Self.Value == Array[T, N] and _MapCompatible[_ArrayFamily[N], Array[T, N], _TupleWith[T, U, False]]:
        """Attach value on the right, moving it for a single call or copying for repeated calls."""
        comptime assert Self.Value == Array[T, N]
        return Piped(_ArrayFamily[N].map(_TupleWith[T, U, False](value^), rebind_var[Array[T, N]](self.value^)))

    def pair_with[P: AnyType, R: Movable & Deinitable, N: Int, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[Array[Tuple[downcast[P, Movable & Deinitable], R], N]] where Self.Value == Array[downcast[P, Movable & Deinitable], N]:
        """Borrow each payload for projection and retain it beside the result."""
        comptime assert Self.Value == Array[downcast[P, Movable & Deinitable], N]
        return Piped(_ArrayFamily[N].map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[Array[downcast[P, Movable & Deinitable], N]](self.value^)))

    def pair_with[P: AnyType, R: Movable & Deinitable, N: Int, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Array[Tuple[downcast[P, Movable & Deinitable], R], N]] where Self.Value == Array[downcast[P, Movable & Deinitable], N]:
        """Borrow each payload for projection and retain it beside the result."""
        comptime assert Self.Value == Array[downcast[P, Movable & Deinitable], N]
        return Piped(_ArrayFamily[N].map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[Array[downcast[P, Movable & Deinitable], N]](self.value^)))

    def pair_with[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, N: Int](deinit self, var function: C) raises C.Failure -> Piped[Array[Tuple[T, C.Result], N]] where Self.Value == Array[T, N] and C.Payload == T and RepeatableBorrow[C]:
        """Borrow each payload for projection and retain it beside the result."""
        comptime assert Self.Value == Array[T, N]
        return Piped(_ArrayFamily[N].map(_Observe[T, C, True](function^), rebind_var[Array[T, N]](self.value^)))

    def tap_each[P: AnyType, R: Movable & Deinitable, N: Int, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[Array[downcast[P, Movable & Deinitable], N]] where Self.Value == Array[downcast[P, Movable & Deinitable], N]:
        """Borrow each payload for inspection and retain it unchanged."""
        comptime assert Self.Value == Array[downcast[P, Movable & Deinitable], N]
        return Piped(_ArrayFamily[N].map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], False](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[Array[downcast[P, Movable & Deinitable], N]](self.value^)))

    def tap_each[P: AnyType, R: Movable & Deinitable, N: Int, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Array[downcast[P, Movable & Deinitable], N]] where Self.Value == Array[downcast[P, Movable & Deinitable], N]:
        """Borrow each payload for inspection and retain it unchanged."""
        comptime assert Self.Value == Array[downcast[P, Movable & Deinitable], N]
        return Piped(_ArrayFamily[N].map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], False](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[Array[downcast[P, Movable & Deinitable], N]](self.value^)))

    def tap_each[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, N: Int](deinit self, var function: C) raises C.Failure -> Piped[Array[T, N]] where Self.Value == Array[T, N] and C.Payload == T and RepeatableBorrow[C]:
        """Borrow each payload for inspection and retain it unchanged."""
        comptime assert Self.Value == Array[T, N]
        return Piped(_ArrayFamily[N].map(_Observe[T, C, False](function^), rebind_var[Array[T, N]](self.value^)))

    def fill[T: Movable & Deinitable, U: Movable & Deinitable](deinit self, var value: U) -> Piped[Deque[U]] where Self.Value == Deque[T] and _MapCompatible[_DequeFamily, Deque[T], _Fill[T, U]]:
        """Replace payloads with value, moving it for a single call or copying for repeated calls."""
        comptime assert Self.Value == Deque[T]
        return Piped(_DequeFamily.map(_Fill[T, U](value^), rebind_var[Deque[T]](self.value^)))

    def replace[T: Copyable & Equatable & Deinitable](deinit self, var old: T, var new: T) -> Piped[Deque[T]] where Self.Value == Deque[T]:
        """Replace equal payloads, moving unmatched values unchanged."""
        comptime assert Self.Value == Deque[T]
        return Piped(_DequeFamily.map(_Replace[T](old^, new^), rebind_var[Deque[T]](self.value^)))

    def void[T: Movable & Deinitable](deinit self) -> Piped[Deque[NoneType]] where Self.Value == Deque[T]:
        """Discard payloads while preserving their container shape."""
        comptime assert Self.Value == Deque[T]
        return Piped(_DequeFamily.map(_Fill[T, NoneType](None), rebind_var[Deque[T]](self.value^)))

    def tuple_left[T: Movable & Deinitable, U: Movable & Deinitable](deinit self, var value: U) -> Piped[Deque[Tuple[U, T]]] where Self.Value == Deque[T] and _MapCompatible[_DequeFamily, Deque[T], _TupleWith[T, U, True]]:
        """Attach value on the left, moving it for a single call or copying for repeated calls."""
        comptime assert Self.Value == Deque[T]
        return Piped(_DequeFamily.map(_TupleWith[T, U, True](value^), rebind_var[Deque[T]](self.value^)))

    def tuple_right[T: Movable & Deinitable, U: Movable & Deinitable](deinit self, var value: U) -> Piped[Deque[Tuple[T, U]]] where Self.Value == Deque[T] and _MapCompatible[_DequeFamily, Deque[T], _TupleWith[T, U, False]]:
        """Attach value on the right, moving it for a single call or copying for repeated calls."""
        comptime assert Self.Value == Deque[T]
        return Piped(_DequeFamily.map(_TupleWith[T, U, False](value^), rebind_var[Deque[T]](self.value^)))

    def pair_with[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[Deque[Tuple[downcast[P, Movable & Deinitable], R]]] where Self.Value == Deque[downcast[P, Movable & Deinitable]]:
        """Borrow each payload for projection and retain it beside the result."""
        comptime assert Self.Value == Deque[downcast[P, Movable & Deinitable]]
        return Piped(_DequeFamily.map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[Deque[downcast[P, Movable & Deinitable]]](self.value^)))

    def pair_with[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Deque[Tuple[downcast[P, Movable & Deinitable], R]]] where Self.Value == Deque[downcast[P, Movable & Deinitable]]:
        """Borrow each payload for projection and retain it beside the result."""
        comptime assert Self.Value == Deque[downcast[P, Movable & Deinitable]]
        return Piped(_DequeFamily.map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[Deque[downcast[P, Movable & Deinitable]]](self.value^)))

    def pair_with[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](deinit self, var function: C) raises C.Failure -> Piped[Deque[Tuple[T, C.Result]]] where Self.Value == Deque[T] and C.Payload == T and RepeatableBorrow[C]:
        """Borrow each payload for projection and retain it beside the result."""
        comptime assert Self.Value == Deque[T]
        return Piped(_DequeFamily.map(_Observe[T, C, True](function^), rebind_var[Deque[T]](self.value^)))

    def tap_each[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[Deque[downcast[P, Movable & Deinitable]]] where Self.Value == Deque[downcast[P, Movable & Deinitable]]:
        """Borrow each payload for inspection and retain it unchanged."""
        comptime assert Self.Value == Deque[downcast[P, Movable & Deinitable]]
        return Piped(_DequeFamily.map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], False](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[Deque[downcast[P, Movable & Deinitable]]](self.value^)))

    def tap_each[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Deque[downcast[P, Movable & Deinitable]]] where Self.Value == Deque[downcast[P, Movable & Deinitable]]:
        """Borrow each payload for inspection and retain it unchanged."""
        comptime assert Self.Value == Deque[downcast[P, Movable & Deinitable]]
        return Piped(_DequeFamily.map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], False](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[Deque[downcast[P, Movable & Deinitable]]](self.value^)))

    def tap_each[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](deinit self, var function: C) raises C.Failure -> Piped[Deque[T]] where Self.Value == Deque[T] and C.Payload == T and RepeatableBorrow[C]:
        """Borrow each payload for inspection and retain it unchanged."""
        comptime assert Self.Value == Deque[T]
        return Piped(_DequeFamily.map(_Observe[T, C, False](function^), rebind_var[Deque[T]](self.value^)))

    def filter_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises _DequeFamily.MapFilterError[Deque[A], _NativeUnaryRef[A, R, Never, F, False, o]] -> Piped[_DequeFamily.MapFiltered[Deque[A], _NativeUnaryRef[A, R, Never, F, False, o]]] where Self.Value == Deque[A]:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        comptime assert Self.Value == Deque[A]
        return Piped(_DequeFamily.filter_map(_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), rebind_var[Deque[A]](self.value^)))

    def filter_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises _DequeFamily.MapFilterError[Deque[A], _NativeUnaryRef[A, R, E, F, True, o]] -> Piped[_DequeFamily.MapFiltered[Deque[A], _NativeUnaryRef[A, R, E, F, True, o]]] where Self.Value == Deque[A]:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        comptime assert Self.Value == Deque[A]
        return Piped(_DequeFamily.filter_map(_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), rebind_var[Deque[A]](self.value^)))

    def filter_map[F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises _DequeFamily.MapFilterError[Deque[F.Arg], F] -> Piped[_DequeFamily.MapFiltered[Deque[F.Arg], F]] where Self.Value == Deque[F.Arg]:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        comptime assert Self.Value == Deque[F.Arg]
        return Piped(_DequeFamily.filter_map(function^, rebind_var[Deque[F.Arg]](self.value^)))

    def filter_map[F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises _DequeFamily.MapFilterError[Deque[F._View[o].Arg], F._View[o]] -> Piped[_DequeFamily.MapFiltered[Deque[F._View[o].Arg], F._View[o]]] where Self.Value == Deque[F._View[o].Arg]:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        comptime assert Self.Value == Deque[F._View[o].Arg]
        return Piped(_DequeFamily.filter_map(function._unary_view(), rebind_var[Deque[F._View[o].Arg]](self.value^)))

    def compact[T: Movable & Deinitable, //](deinit self) raises _DequeFamily.MapFilterError[Deque[Optional[T]], _Same[Optional[T]]] -> Piped[_DequeFamily.MapFiltered[Deque[Optional[T]], _Same[Optional[T]]]] where Self.Value == Deque[Optional[T]]:
        """Derive compact through filter_map, preserving the family's semantics."""
        comptime assert Self.Value == Deque[Optional[T]]
        return Piped(_DequeFamily.filter_map(_Same[Optional[T]](), rebind_var[Deque[Optional[T]]](self.value^)))

    def fill[T: Movable & Deinitable, U: Movable & Deinitable](deinit self, var value: U) -> Piped[LinkedList[U]] where Self.Value == LinkedList[T] and _MapCompatible[_LinkedListFamily, LinkedList[T], _Fill[T, U]]:
        """Replace payloads with value, moving it for a single call or copying for repeated calls."""
        comptime assert Self.Value == LinkedList[T]
        return Piped(_LinkedListFamily.map(_Fill[T, U](value^), rebind_var[LinkedList[T]](self.value^)))

    def replace[T: Copyable & Equatable & Deinitable](deinit self, var old: T, var new: T) -> Piped[LinkedList[T]] where Self.Value == LinkedList[T]:
        """Replace equal payloads, moving unmatched values unchanged."""
        comptime assert Self.Value == LinkedList[T]
        return Piped(_LinkedListFamily.map(_Replace[T](old^, new^), rebind_var[LinkedList[T]](self.value^)))

    def void[T: Movable & Deinitable](deinit self) -> Piped[LinkedList[NoneType]] where Self.Value == LinkedList[T]:
        """Discard payloads while preserving their container shape."""
        comptime assert Self.Value == LinkedList[T]
        return Piped(_LinkedListFamily.map(_Fill[T, NoneType](None), rebind_var[LinkedList[T]](self.value^)))

    def tuple_left[T: Movable & Deinitable, U: Movable & Deinitable](deinit self, var value: U) -> Piped[LinkedList[Tuple[U, T]]] where Self.Value == LinkedList[T] and _MapCompatible[_LinkedListFamily, LinkedList[T], _TupleWith[T, U, True]]:
        """Attach value on the left, moving it for a single call or copying for repeated calls."""
        comptime assert Self.Value == LinkedList[T]
        return Piped(_LinkedListFamily.map(_TupleWith[T, U, True](value^), rebind_var[LinkedList[T]](self.value^)))

    def tuple_right[T: Movable & Deinitable, U: Movable & Deinitable](deinit self, var value: U) -> Piped[LinkedList[Tuple[T, U]]] where Self.Value == LinkedList[T] and _MapCompatible[_LinkedListFamily, LinkedList[T], _TupleWith[T, U, False]]:
        """Attach value on the right, moving it for a single call or copying for repeated calls."""
        comptime assert Self.Value == LinkedList[T]
        return Piped(_LinkedListFamily.map(_TupleWith[T, U, False](value^), rebind_var[LinkedList[T]](self.value^)))

    def pair_with[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[LinkedList[Tuple[downcast[P, Movable & Deinitable], R]]] where Self.Value == LinkedList[downcast[P, Movable & Deinitable]]:
        """Borrow each payload for projection and retain it beside the result."""
        comptime assert Self.Value == LinkedList[downcast[P, Movable & Deinitable]]
        return Piped(_LinkedListFamily.map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[LinkedList[downcast[P, Movable & Deinitable]]](self.value^)))

    def pair_with[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[LinkedList[Tuple[downcast[P, Movable & Deinitable], R]]] where Self.Value == LinkedList[downcast[P, Movable & Deinitable]]:
        """Borrow each payload for projection and retain it beside the result."""
        comptime assert Self.Value == LinkedList[downcast[P, Movable & Deinitable]]
        return Piped(_LinkedListFamily.map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[LinkedList[downcast[P, Movable & Deinitable]]](self.value^)))

    def pair_with[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](deinit self, var function: C) raises C.Failure -> Piped[LinkedList[Tuple[T, C.Result]]] where Self.Value == LinkedList[T] and C.Payload == T and RepeatableBorrow[C]:
        """Borrow each payload for projection and retain it beside the result."""
        comptime assert Self.Value == LinkedList[T]
        return Piped(_LinkedListFamily.map(_Observe[T, C, True](function^), rebind_var[LinkedList[T]](self.value^)))

    def tap_each[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[LinkedList[downcast[P, Movable & Deinitable]]] where Self.Value == LinkedList[downcast[P, Movable & Deinitable]]:
        """Borrow each payload for inspection and retain it unchanged."""
        comptime assert Self.Value == LinkedList[downcast[P, Movable & Deinitable]]
        return Piped(_LinkedListFamily.map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], False](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[LinkedList[downcast[P, Movable & Deinitable]]](self.value^)))

    def tap_each[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[LinkedList[downcast[P, Movable & Deinitable]]] where Self.Value == LinkedList[downcast[P, Movable & Deinitable]]:
        """Borrow each payload for inspection and retain it unchanged."""
        comptime assert Self.Value == LinkedList[downcast[P, Movable & Deinitable]]
        return Piped(_LinkedListFamily.map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], False](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[LinkedList[downcast[P, Movable & Deinitable]]](self.value^)))

    def tap_each[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](deinit self, var function: C) raises C.Failure -> Piped[LinkedList[T]] where Self.Value == LinkedList[T] and C.Payload == T and RepeatableBorrow[C]:
        """Borrow each payload for inspection and retain it unchanged."""
        comptime assert Self.Value == LinkedList[T]
        return Piped(_LinkedListFamily.map(_Observe[T, C, False](function^), rebind_var[LinkedList[T]](self.value^)))

    def filter_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises _LinkedListFamily.MapFilterError[LinkedList[A], _NativeUnaryRef[A, R, Never, F, False, o]] -> Piped[_LinkedListFamily.MapFiltered[LinkedList[A], _NativeUnaryRef[A, R, Never, F, False, o]]] where Self.Value == LinkedList[A]:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        comptime assert Self.Value == LinkedList[A]
        return Piped(_LinkedListFamily.filter_map(_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), rebind_var[LinkedList[A]](self.value^)))

    def filter_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises _LinkedListFamily.MapFilterError[LinkedList[A], _NativeUnaryRef[A, R, E, F, True, o]] -> Piped[_LinkedListFamily.MapFiltered[LinkedList[A], _NativeUnaryRef[A, R, E, F, True, o]]] where Self.Value == LinkedList[A]:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        comptime assert Self.Value == LinkedList[A]
        return Piped(_LinkedListFamily.filter_map(_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), rebind_var[LinkedList[A]](self.value^)))

    def filter_map[F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises _LinkedListFamily.MapFilterError[LinkedList[F.Arg], F] -> Piped[_LinkedListFamily.MapFiltered[LinkedList[F.Arg], F]] where Self.Value == LinkedList[F.Arg]:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        comptime assert Self.Value == LinkedList[F.Arg]
        return Piped(_LinkedListFamily.filter_map(function^, rebind_var[LinkedList[F.Arg]](self.value^)))

    def filter_map[F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises _LinkedListFamily.MapFilterError[LinkedList[F._View[o].Arg], F._View[o]] -> Piped[_LinkedListFamily.MapFiltered[LinkedList[F._View[o].Arg], F._View[o]]] where Self.Value == LinkedList[F._View[o].Arg]:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        comptime assert Self.Value == LinkedList[F._View[o].Arg]
        return Piped(_LinkedListFamily.filter_map(function._unary_view(), rebind_var[LinkedList[F._View[o].Arg]](self.value^)))

    def compact[T: Movable & Deinitable, //](deinit self) raises _LinkedListFamily.MapFilterError[LinkedList[Optional[T]], _Same[Optional[T]]] -> Piped[_LinkedListFamily.MapFiltered[LinkedList[Optional[T]], _Same[Optional[T]]]] where Self.Value == LinkedList[Optional[T]]:
        """Derive compact through filter_map, preserving the family's semantics."""
        comptime assert Self.Value == LinkedList[Optional[T]]
        return Piped(_LinkedListFamily.filter_map(_Same[Optional[T]](), rebind_var[LinkedList[Optional[T]]](self.value^)))

    def fill[T: Movable & Deinitable, U: Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable](deinit self, var value: U) -> Piped[Dict[K, U, H]] where Self.Value == Dict[K, T, H] and _MapCompatible[_DictFamily[K, T, H], Dict[K, T, H], _Fill[T, U]]:
        """Replace payloads with value, moving it for a single call or copying for repeated calls."""
        comptime assert Self.Value == Dict[K, T, H]
        return Piped(_DictFamily[K, T, H].map(_Fill[T, U](value^), rebind_var[Dict[K, T, H]](self.value^)))

    def replace[T: Copyable & Equatable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable](deinit self, var old: T, var new: T) -> Piped[Dict[K, T, H]] where Self.Value == Dict[K, T, H]:
        """Replace equal payloads, moving unmatched values unchanged."""
        comptime assert Self.Value == Dict[K, T, H]
        return Piped(_DictFamily[K, T, H].map(_Replace[T](old^, new^), rebind_var[Dict[K, T, H]](self.value^)))

    def void[T: Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable](deinit self) -> Piped[Dict[K, NoneType, H]] where Self.Value == Dict[K, T, H]:
        """Discard payloads while preserving their container shape."""
        comptime assert Self.Value == Dict[K, T, H]
        return Piped(_DictFamily[K, T, H].map(_Fill[T, NoneType](None), rebind_var[Dict[K, T, H]](self.value^)))

    def tuple_left[T: Movable & Deinitable, U: Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable](deinit self, var value: U) -> Piped[Dict[K, Tuple[U, T], H]] where Self.Value == Dict[K, T, H] and _MapCompatible[_DictFamily[K, T, H], Dict[K, T, H], _TupleWith[T, U, True]]:
        """Attach value on the left, moving it for a single call or copying for repeated calls."""
        comptime assert Self.Value == Dict[K, T, H]
        return Piped(_DictFamily[K, T, H].map(_TupleWith[T, U, True](value^), rebind_var[Dict[K, T, H]](self.value^)))

    def tuple_right[T: Movable & Deinitable, U: Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable](deinit self, var value: U) -> Piped[Dict[K, Tuple[T, U], H]] where Self.Value == Dict[K, T, H] and _MapCompatible[_DictFamily[K, T, H], Dict[K, T, H], _TupleWith[T, U, False]]:
        """Attach value on the right, moving it for a single call or copying for repeated calls."""
        comptime assert Self.Value == Dict[K, T, H]
        return Piped(_DictFamily[K, T, H].map(_TupleWith[T, U, False](value^), rebind_var[Dict[K, T, H]](self.value^)))

    def pair_with[P: AnyType, R: Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[Dict[K, Tuple[downcast[P, Movable & Deinitable], R], H]] where Self.Value == Dict[K, downcast[P, Movable & Deinitable], H]:
        """Borrow each payload for projection and retain it beside the result."""
        comptime assert Self.Value == Dict[K, downcast[P, Movable & Deinitable], H]
        return Piped(_DictFamily[K, downcast[P, Movable & Deinitable], H].map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[Dict[K, downcast[P, Movable & Deinitable], H]](self.value^)))

    def pair_with[P: AnyType, R: Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Dict[K, Tuple[downcast[P, Movable & Deinitable], R], H]] where Self.Value == Dict[K, downcast[P, Movable & Deinitable], H]:
        """Borrow each payload for projection and retain it beside the result."""
        comptime assert Self.Value == Dict[K, downcast[P, Movable & Deinitable], H]
        return Piped(_DictFamily[K, downcast[P, Movable & Deinitable], H].map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[Dict[K, downcast[P, Movable & Deinitable], H]](self.value^)))

    def pair_with[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable](deinit self, var function: C) raises C.Failure -> Piped[Dict[K, Tuple[T, C.Result], H]] where Self.Value == Dict[K, T, H] and C.Payload == T and RepeatableBorrow[C]:
        """Borrow each payload for projection and retain it beside the result."""
        comptime assert Self.Value == Dict[K, T, H]
        return Piped(_DictFamily[K, T, H].map(_Observe[T, C, True](function^), rebind_var[Dict[K, T, H]](self.value^)))

    def tap_each[P: AnyType, R: Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[Dict[K, downcast[P, Movable & Deinitable], H]] where Self.Value == Dict[K, downcast[P, Movable & Deinitable], H]:
        """Borrow each payload for inspection and retain it unchanged."""
        comptime assert Self.Value == Dict[K, downcast[P, Movable & Deinitable], H]
        return Piped(_DictFamily[K, downcast[P, Movable & Deinitable], H].map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], False](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[Dict[K, downcast[P, Movable & Deinitable], H]](self.value^)))

    def tap_each[P: AnyType, R: Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Dict[K, downcast[P, Movable & Deinitable], H]] where Self.Value == Dict[K, downcast[P, Movable & Deinitable], H]:
        """Borrow each payload for inspection and retain it unchanged."""
        comptime assert Self.Value == Dict[K, downcast[P, Movable & Deinitable], H]
        return Piped(_DictFamily[K, downcast[P, Movable & Deinitable], H].map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], False](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[Dict[K, downcast[P, Movable & Deinitable], H]](self.value^)))

    def tap_each[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable](deinit self, var function: C) raises C.Failure -> Piped[Dict[K, T, H]] where Self.Value == Dict[K, T, H] and C.Payload == T and RepeatableBorrow[C]:
        """Borrow each payload for inspection and retain it unchanged."""
        comptime assert Self.Value == Dict[K, T, H]
        return Piped(_DictFamily[K, T, H].map(_Observe[T, C, False](function^), rebind_var[Dict[K, T, H]](self.value^)))

    def filter_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises _DictFamily[K, A, H].MapFilterError[Dict[K, A, H], _NativeUnaryRef[A, R, Never, F, False, o]] -> Piped[_DictFamily[K, A, H].MapFiltered[Dict[K, A, H], _NativeUnaryRef[A, R, Never, F, False, o]]] where Self.Value == Dict[K, A, H]:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        comptime assert Self.Value == Dict[K, A, H]
        return Piped(_DictFamily[K, A, H].filter_map(_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), rebind_var[Dict[K, A, H]](self.value^)))

    def filter_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises _DictFamily[K, A, H].MapFilterError[Dict[K, A, H], _NativeUnaryRef[A, R, E, F, True, o]] -> Piped[_DictFamily[K, A, H].MapFiltered[Dict[K, A, H], _NativeUnaryRef[A, R, E, F, True, o]]] where Self.Value == Dict[K, A, H]:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        comptime assert Self.Value == Dict[K, A, H]
        return Piped(_DictFamily[K, A, H].filter_map(_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), rebind_var[Dict[K, A, H]](self.value^)))

    def filter_map[F: UnaryContract & Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //](deinit self, var function: F) raises _DictFamily[K, F.Arg, H].MapFilterError[Dict[K, F.Arg, H], F] -> Piped[_DictFamily[K, F.Arg, H].MapFiltered[Dict[K, F.Arg, H], F]] where Self.Value == Dict[K, F.Arg, H]:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        comptime assert Self.Value == Dict[K, F.Arg, H]
        return Piped(_DictFamily[K, F.Arg, H].filter_map(function^, rebind_var[Dict[K, F.Arg, H]](self.value^)))

    def filter_map[F: _UnaryViewable, o: ImmOrigin, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //](deinit self, ref[o] function: F) raises _DictFamily[K, F._View[o].Arg, H].MapFilterError[Dict[K, F._View[o].Arg, H], F._View[o]] -> Piped[_DictFamily[K, F._View[o].Arg, H].MapFiltered[Dict[K, F._View[o].Arg, H], F._View[o]]] where Self.Value == Dict[K, F._View[o].Arg, H]:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        comptime assert Self.Value == Dict[K, F._View[o].Arg, H]
        return Piped(_DictFamily[K, F._View[o].Arg, H].filter_map(function._unary_view(), rebind_var[Dict[K, F._View[o].Arg, H]](self.value^)))

    def compact[T: Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //](deinit self) raises _DictFamily[K, Optional[T], H].MapFilterError[Dict[K, Optional[T], H], _Same[Optional[T]]] -> Piped[_DictFamily[K, Optional[T], H].MapFiltered[Dict[K, Optional[T], H], _Same[Optional[T]]]] where Self.Value == Dict[K, Optional[T], H]:
        """Derive compact through filter_map, preserving the family's semantics."""
        comptime assert Self.Value == Dict[K, Optional[T], H]
        return Piped(_DictFamily[K, Optional[T], H].filter_map(_Same[Optional[T]](), rebind_var[Dict[K, Optional[T], H]](self.value^)))

    def fill[T: Movable & Deinitable, U: Movable & Deinitable](deinit self, var value: U) -> Piped[StringDict[U]] where Self.Value == StringDict[T] and _MapCompatible[_StringDictFamily[T], StringDict[T], _Fill[T, U]]:
        """Replace payloads with value, moving it for a single call or copying for repeated calls."""
        comptime assert Self.Value == StringDict[T]
        return Piped(_StringDictFamily[T].map(_Fill[T, U](value^), rebind_var[StringDict[T]](self.value^)))

    def replace[T: Copyable & Equatable & Deinitable](deinit self, var old: T, var new: T) -> Piped[StringDict[T]] where Self.Value == StringDict[T]:
        """Replace equal payloads, moving unmatched values unchanged."""
        comptime assert Self.Value == StringDict[T]
        return Piped(_StringDictFamily[T].map(_Replace[T](old^, new^), rebind_var[StringDict[T]](self.value^)))

    def void[T: Movable & Deinitable](deinit self) -> Piped[StringDict[NoneType]] where Self.Value == StringDict[T]:
        """Discard payloads while preserving their container shape."""
        comptime assert Self.Value == StringDict[T]
        return Piped(_StringDictFamily[T].map(_Fill[T, NoneType](None), rebind_var[StringDict[T]](self.value^)))

    def tuple_left[T: Movable & Deinitable, U: Movable & Deinitable](deinit self, var value: U) -> Piped[StringDict[Tuple[U, T]]] where Self.Value == StringDict[T] and _MapCompatible[_StringDictFamily[T], StringDict[T], _TupleWith[T, U, True]]:
        """Attach value on the left, moving it for a single call or copying for repeated calls."""
        comptime assert Self.Value == StringDict[T]
        return Piped(_StringDictFamily[T].map(_TupleWith[T, U, True](value^), rebind_var[StringDict[T]](self.value^)))

    def tuple_right[T: Movable & Deinitable, U: Movable & Deinitable](deinit self, var value: U) -> Piped[StringDict[Tuple[T, U]]] where Self.Value == StringDict[T] and _MapCompatible[_StringDictFamily[T], StringDict[T], _TupleWith[T, U, False]]:
        """Attach value on the right, moving it for a single call or copying for repeated calls."""
        comptime assert Self.Value == StringDict[T]
        return Piped(_StringDictFamily[T].map(_TupleWith[T, U, False](value^), rebind_var[StringDict[T]](self.value^)))

    def pair_with[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[StringDict[Tuple[downcast[P, Movable & Deinitable], R]]] where Self.Value == StringDict[downcast[P, Movable & Deinitable]]:
        """Borrow each payload for projection and retain it beside the result."""
        comptime assert Self.Value == StringDict[downcast[P, Movable & Deinitable]]
        return Piped(_StringDictFamily[downcast[P, Movable & Deinitable]].map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[StringDict[downcast[P, Movable & Deinitable]]](self.value^)))

    def pair_with[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[StringDict[Tuple[downcast[P, Movable & Deinitable], R]]] where Self.Value == StringDict[downcast[P, Movable & Deinitable]]:
        """Borrow each payload for projection and retain it beside the result."""
        comptime assert Self.Value == StringDict[downcast[P, Movable & Deinitable]]
        return Piped(_StringDictFamily[downcast[P, Movable & Deinitable]].map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[StringDict[downcast[P, Movable & Deinitable]]](self.value^)))

    def pair_with[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](deinit self, var function: C) raises C.Failure -> Piped[StringDict[Tuple[T, C.Result]]] where Self.Value == StringDict[T] and C.Payload == T and RepeatableBorrow[C]:
        """Borrow each payload for projection and retain it beside the result."""
        comptime assert Self.Value == StringDict[T]
        return Piped(_StringDictFamily[T].map(_Observe[T, C, True](function^), rebind_var[StringDict[T]](self.value^)))

    def tap_each[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[StringDict[downcast[P, Movable & Deinitable]]] where Self.Value == StringDict[downcast[P, Movable & Deinitable]]:
        """Borrow each payload for inspection and retain it unchanged."""
        comptime assert Self.Value == StringDict[downcast[P, Movable & Deinitable]]
        return Piped(_StringDictFamily[downcast[P, Movable & Deinitable]].map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], False](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[StringDict[downcast[P, Movable & Deinitable]]](self.value^)))

    def tap_each[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[StringDict[downcast[P, Movable & Deinitable]]] where Self.Value == StringDict[downcast[P, Movable & Deinitable]]:
        """Borrow each payload for inspection and retain it unchanged."""
        comptime assert Self.Value == StringDict[downcast[P, Movable & Deinitable]]
        return Piped(_StringDictFamily[downcast[P, Movable & Deinitable]].map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], False](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[StringDict[downcast[P, Movable & Deinitable]]](self.value^)))

    def tap_each[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](deinit self, var function: C) raises C.Failure -> Piped[StringDict[T]] where Self.Value == StringDict[T] and C.Payload == T and RepeatableBorrow[C]:
        """Borrow each payload for inspection and retain it unchanged."""
        comptime assert Self.Value == StringDict[T]
        return Piped(_StringDictFamily[T].map(_Observe[T, C, False](function^), rebind_var[StringDict[T]](self.value^)))

    def filter_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises _StringDictFamily[A].MapFilterError[StringDict[A], _NativeUnaryRef[A, R, Never, F, False, o]] -> Piped[_StringDictFamily[A].MapFiltered[StringDict[A], _NativeUnaryRef[A, R, Never, F, False, o]]] where Self.Value == StringDict[A]:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        comptime assert Self.Value == StringDict[A]
        return Piped(_StringDictFamily[A].filter_map(_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), rebind_var[StringDict[A]](self.value^)))

    def filter_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises _StringDictFamily[A].MapFilterError[StringDict[A], _NativeUnaryRef[A, R, E, F, True, o]] -> Piped[_StringDictFamily[A].MapFiltered[StringDict[A], _NativeUnaryRef[A, R, E, F, True, o]]] where Self.Value == StringDict[A]:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        comptime assert Self.Value == StringDict[A]
        return Piped(_StringDictFamily[A].filter_map(_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), rebind_var[StringDict[A]](self.value^)))

    def filter_map[F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises _StringDictFamily[F.Arg].MapFilterError[StringDict[F.Arg], F] -> Piped[_StringDictFamily[F.Arg].MapFiltered[StringDict[F.Arg], F]] where Self.Value == StringDict[F.Arg]:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        comptime assert Self.Value == StringDict[F.Arg]
        return Piped(_StringDictFamily[F.Arg].filter_map(function^, rebind_var[StringDict[F.Arg]](self.value^)))

    def filter_map[F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises _StringDictFamily[F._View[o].Arg].MapFilterError[StringDict[F._View[o].Arg], F._View[o]] -> Piped[_StringDictFamily[F._View[o].Arg].MapFiltered[StringDict[F._View[o].Arg], F._View[o]]] where Self.Value == StringDict[F._View[o].Arg]:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        comptime assert Self.Value == StringDict[F._View[o].Arg]
        return Piped(_StringDictFamily[F._View[o].Arg].filter_map(function._unary_view(), rebind_var[StringDict[F._View[o].Arg]](self.value^)))

    def compact[T: Movable & Deinitable, //](deinit self) raises _StringDictFamily[Optional[T]].MapFilterError[StringDict[Optional[T]], _Same[Optional[T]]] -> Piped[_StringDictFamily[Optional[T]].MapFiltered[StringDict[Optional[T]], _Same[Optional[T]]]] where Self.Value == StringDict[Optional[T]]:
        """Derive compact through filter_map, preserving the family's semantics."""
        comptime assert Self.Value == StringDict[Optional[T]]
        return Piped(_StringDictFamily[Optional[T]].filter_map(_Same[Optional[T]](), rebind_var[StringDict[Optional[T]]](self.value^)))

    def fill[T: Movable & Deinitable, U: Movable & Deinitable](deinit self, var value: U) -> Piped[Optional[U]] where Self.Value == Optional[T] and _MapCompatible[OptionalFamily, Optional[T], _Fill[T, U]]:
        """Replace payloads with value, moving it for a single call or copying for repeated calls."""
        comptime assert Self.Value == Optional[T]
        return Piped(OptionalFamily.map(_Fill[T, U](value^), rebind_var[Optional[T]](self.value^)))

    def replace[T: Copyable & Equatable & Deinitable](deinit self, var old: T, var new: T) -> Piped[Optional[T]] where Self.Value == Optional[T]:
        """Replace equal payloads, moving unmatched values unchanged."""
        comptime assert Self.Value == Optional[T]
        return Piped(OptionalFamily.map(_Replace[T](old^, new^), rebind_var[Optional[T]](self.value^)))

    def void[T: Movable & Deinitable](deinit self) -> Piped[Optional[NoneType]] where Self.Value == Optional[T]:
        """Discard payloads while preserving their container shape."""
        comptime assert Self.Value == Optional[T]
        return Piped(OptionalFamily.map(_Fill[T, NoneType](None), rebind_var[Optional[T]](self.value^)))

    def tuple_left[T: Movable & Deinitable, U: Movable & Deinitable](deinit self, var value: U) -> Piped[Optional[Tuple[U, T]]] where Self.Value == Optional[T] and _MapCompatible[OptionalFamily, Optional[T], _TupleWith[T, U, True]]:
        """Attach value on the left, moving it for a single call or copying for repeated calls."""
        comptime assert Self.Value == Optional[T]
        return Piped(OptionalFamily.map(_TupleWith[T, U, True](value^), rebind_var[Optional[T]](self.value^)))

    def tuple_right[T: Movable & Deinitable, U: Movable & Deinitable](deinit self, var value: U) -> Piped[Optional[Tuple[T, U]]] where Self.Value == Optional[T] and _MapCompatible[OptionalFamily, Optional[T], _TupleWith[T, U, False]]:
        """Attach value on the right, moving it for a single call or copying for repeated calls."""
        comptime assert Self.Value == Optional[T]
        return Piped(OptionalFamily.map(_TupleWith[T, U, False](value^), rebind_var[Optional[T]](self.value^)))

    def pair_with[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[Optional[Tuple[downcast[P, Movable & Deinitable], R]]] where Self.Value == Optional[downcast[P, Movable & Deinitable]]:
        """Borrow each payload for projection and retain it beside the result."""
        comptime assert Self.Value == Optional[downcast[P, Movable & Deinitable]]
        return Piped(OptionalFamily.map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[Optional[downcast[P, Movable & Deinitable]]](self.value^)))

    def pair_with[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Optional[Tuple[downcast[P, Movable & Deinitable], R]]] where Self.Value == Optional[downcast[P, Movable & Deinitable]]:
        """Borrow each payload for projection and retain it beside the result."""
        comptime assert Self.Value == Optional[downcast[P, Movable & Deinitable]]
        return Piped(OptionalFamily.map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[Optional[downcast[P, Movable & Deinitable]]](self.value^)))

    def pair_with[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](deinit self, var function: C) raises C.Failure -> Piped[Optional[Tuple[T, C.Result]]] where Self.Value == Optional[T] and C.Payload == T and RepeatableBorrow[C]:
        """Borrow each payload for projection and retain it beside the result."""
        comptime assert Self.Value == Optional[T]
        return Piped(OptionalFamily.map(_Observe[T, C, True](function^), rebind_var[Optional[T]](self.value^)))

    def tap_each[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == Optional[downcast[P, Movable & Deinitable]]:
        """Borrow each payload for inspection and retain it unchanged."""
        comptime assert Self.Value == Optional[downcast[P, Movable & Deinitable]]
        return Piped(OptionalFamily.map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], False](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[Optional[downcast[P, Movable & Deinitable]]](self.value^)))

    def tap_each[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == Optional[downcast[P, Movable & Deinitable]]:
        """Borrow each payload for inspection and retain it unchanged."""
        comptime assert Self.Value == Optional[downcast[P, Movable & Deinitable]]
        return Piped(OptionalFamily.map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], False](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[Optional[downcast[P, Movable & Deinitable]]](self.value^)))

    def tap_each[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](deinit self, var function: C) raises C.Failure -> Piped[Optional[T]] where Self.Value == Optional[T] and C.Payload == T and RepeatableBorrow[C]:
        """Borrow each payload for inspection and retain it unchanged."""
        comptime assert Self.Value == Optional[T]
        return Piped(OptionalFamily.map(_Observe[T, C, False](function^), rebind_var[Optional[T]](self.value^)))

    def filter_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises OptionalFamily.MapFilterError[Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]] -> Piped[OptionalFamily.MapFiltered[Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]]] where Self.Value == Optional[A]:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        comptime assert Self.Value == Optional[A]
        return Piped(OptionalFamily.filter_map(_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), rebind_var[Optional[A]](self.value^)))

    def filter_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises OptionalFamily.MapFilterError[Optional[A], _NativeUnaryRef[A, R, E, F, True, o]] -> Piped[OptionalFamily.MapFiltered[Optional[A], _NativeUnaryRef[A, R, E, F, True, o]]] where Self.Value == Optional[A]:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        comptime assert Self.Value == Optional[A]
        return Piped(OptionalFamily.filter_map(_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), rebind_var[Optional[A]](self.value^)))

    def filter_map[F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises OptionalFamily.MapFilterError[Optional[F.Arg], F] -> Piped[OptionalFamily.MapFiltered[Optional[F.Arg], F]] where Self.Value == Optional[F.Arg]:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        comptime assert Self.Value == Optional[F.Arg]
        return Piped(OptionalFamily.filter_map(function^, rebind_var[Optional[F.Arg]](self.value^)))

    def filter_map[F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises OptionalFamily.MapFilterError[Optional[F._View[o].Arg], F._View[o]] -> Piped[OptionalFamily.MapFiltered[Optional[F._View[o].Arg], F._View[o]]] where Self.Value == Optional[F._View[o].Arg]:
        """Apply filter_map through the carrier's FunctorFilter capability."""
        comptime assert Self.Value == Optional[F._View[o].Arg]
        return Piped(OptionalFamily.filter_map(function._unary_view(), rebind_var[Optional[F._View[o].Arg]](self.value^)))

    def flat_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises OptionalFamily.BindError[Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]] -> Piped[OptionalFamily.Bound[Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]]] where Self.Value == Optional[A]:
        """Apply flat_map through the carrier's Monad capability."""
        comptime assert Self.Value == Optional[A]
        return Piped(OptionalFamily.flat_map(_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), rebind_var[Optional[A]](self.value^)))

    def flat_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises OptionalFamily.BindError[Optional[A], _NativeUnaryRef[A, R, E, F, True, o]] -> Piped[OptionalFamily.Bound[Optional[A], _NativeUnaryRef[A, R, E, F, True, o]]] where Self.Value == Optional[A]:
        """Apply flat_map through the carrier's Monad capability."""
        comptime assert Self.Value == Optional[A]
        return Piped(OptionalFamily.flat_map(_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), rebind_var[Optional[A]](self.value^)))

    def flat_map[F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises OptionalFamily.BindError[Optional[F.Arg], F] -> Piped[OptionalFamily.Bound[Optional[F.Arg], F]] where Self.Value == Optional[F.Arg]:
        """Apply flat_map through the carrier's Monad capability."""
        comptime assert Self.Value == Optional[F.Arg]
        return Piped(OptionalFamily.flat_map(function^, rebind_var[Optional[F.Arg]](self.value^)))

    def flat_map[F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises OptionalFamily.BindError[Optional[F._View[o].Arg], F._View[o]] -> Piped[OptionalFamily.Bound[Optional[F._View[o].Arg], F._View[o]]] where Self.Value == Optional[F._View[o].Arg]:
        """Apply flat_map through the carrier's Monad capability."""
        comptime assert Self.Value == Optional[F._View[o].Arg]
        return Piped(OptionalFamily.flat_map(function._unary_view(), rebind_var[Optional[F._View[o].Arg]](self.value^)))

    def traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, F: _Unary[A, R]](deinit self, ref[o] function: F) raises OptionalFamily.TraverseError[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]] -> Piped[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]]] where Self.Value == Optional[A] and OptionalFamily.TargetCompatible[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]]:
        """Apply traverse through the carrier's Traversable capability."""
        comptime assert Self.Value == Optional[A]
        return Piped(OptionalFamily.traverse[G](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), rebind_var[Optional[A]](self.value^)))

    def traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises OptionalFamily.TraverseError[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]] -> Piped[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]]] where Self.Value == Optional[A] and OptionalFamily.TargetCompatible[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]]:
        """Apply traverse through the carrier's Traversable capability."""
        comptime assert Self.Value == Optional[A]
        return Piped(OptionalFamily.traverse[G](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), rebind_var[Optional[A]](self.value^)))

    def traverse[F: UnaryContract & Movable & Deinitable, //, G: Applicative](deinit self, var function: F) raises OptionalFamily.TraverseError[G, Optional[F.Arg], F] -> Piped[OptionalFamily.Traversed[G, Optional[F.Arg], F]] where Self.Value == Optional[F.Arg] and OptionalFamily.TargetCompatible[G, Optional[F.Arg], F]:
        """Apply traverse through the carrier's Traversable capability."""
        comptime assert Self.Value == Optional[F.Arg]
        return Piped(OptionalFamily.traverse[G](function^, rebind_var[Optional[F.Arg]](self.value^)))

    def traverse[F: _UnaryViewable, o: ImmOrigin, //, G: Applicative](deinit self, ref[o] function: F) raises OptionalFamily.TraverseError[G, Optional[F._View[o].Arg], F._View[o]] -> Piped[OptionalFamily.Traversed[G, Optional[F._View[o].Arg], F._View[o]]] where Self.Value == Optional[F._View[o].Arg] and OptionalFamily.TargetCompatible[G, Optional[F._View[o].Arg], F._View[o]]:
        """Apply traverse through the carrier's Traversable capability."""
        comptime assert Self.Value == Optional[F._View[o].Arg]
        return Piped(OptionalFamily.traverse[G](function._unary_view(), rebind_var[Optional[F._View[o].Arg]](self.value^)))

    def par_traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, F: _Unary[A, R], //, S: Semigroup = _ListErrors[R]](deinit self, ref[o] function: F) raises OptionalFamily.TraverseError[ValidationFamily[S], Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]] -> Piped[OptionalFamily.Traversed[ValidationFamily[S], Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]]] where Self.Value == Optional[A] and OptionalFamily.TargetCompatible[ValidationFamily[S], Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]] and _CarrierCompatible[ValidationFamily[S], R]:
        """Apply par_traverse through the carrier's Traversable capability."""
        comptime assert Self.Value == Optional[A]
        return Piped(OptionalFamily.traverse[ValidationFamily[S]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), rebind_var[Optional[A]](self.value^)))

    def par_traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], //, S: Semigroup = _ListErrors[R]](deinit self, ref[o] function: F) raises OptionalFamily.TraverseError[ValidationFamily[S], Optional[A], _NativeUnaryRef[A, R, E, F, True, o]] -> Piped[OptionalFamily.Traversed[ValidationFamily[S], Optional[A], _NativeUnaryRef[A, R, E, F, True, o]]] where Self.Value == Optional[A] and OptionalFamily.TargetCompatible[ValidationFamily[S], Optional[A], _NativeUnaryRef[A, R, E, F, True, o]] and _CarrierCompatible[ValidationFamily[S], R]:
        """Apply par_traverse through the carrier's Traversable capability."""
        comptime assert Self.Value == Optional[A]
        return Piped(OptionalFamily.traverse[ValidationFamily[S]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), rebind_var[Optional[A]](self.value^)))

    def par_traverse[F: UnaryContract & Movable & Deinitable, //, S: Semigroup = _ListErrors[F.Out]](deinit self, var function: F) raises OptionalFamily.TraverseError[ValidationFamily[S], Optional[F.Arg], F] -> Piped[OptionalFamily.Traversed[ValidationFamily[S], Optional[F.Arg], F]] where Self.Value == Optional[F.Arg] and OptionalFamily.TargetCompatible[ValidationFamily[S], Optional[F.Arg], F] and _CarrierCompatible[ValidationFamily[S], F.Out]:
        """Apply par_traverse through the carrier's Traversable capability."""
        comptime assert Self.Value == Optional[F.Arg]
        return Piped(OptionalFamily.traverse[ValidationFamily[S]](function^, rebind_var[Optional[F.Arg]](self.value^)))

    def par_traverse[F: _UnaryViewable, o: ImmOrigin, //, S: Semigroup = _ListErrors[F._View[o].Out]](deinit self, ref[o] function: F) raises OptionalFamily.TraverseError[ValidationFamily[S], Optional[F._View[o].Arg], F._View[o]] -> Piped[OptionalFamily.Traversed[ValidationFamily[S], Optional[F._View[o].Arg], F._View[o]]] where Self.Value == Optional[F._View[o].Arg] and OptionalFamily.TargetCompatible[ValidationFamily[S], Optional[F._View[o].Arg], F._View[o]] and _CarrierCompatible[ValidationFamily[S], F._View[o].Out]:
        """Apply par_traverse through the carrier's Traversable capability."""
        comptime assert Self.Value == Optional[F._View[o].Arg]
        return Piped(OptionalFamily.traverse[ValidationFamily[S]](function._unary_view(), rebind_var[Optional[F._View[o].Arg]](self.value^)))

    def compact[T: Movable & Deinitable, //](deinit self) raises OptionalFamily.MapFilterError[Optional[Optional[T]], _Same[Optional[T]]] -> Piped[OptionalFamily.MapFiltered[Optional[Optional[T]], _Same[Optional[T]]]] where Self.Value == Optional[Optional[T]]:
        """Derive compact through filter_map, preserving the family's semantics."""
        comptime assert Self.Value == Optional[Optional[T]]
        return Piped(OptionalFamily.filter_map(_Same[Optional[T]](), rebind_var[Optional[Optional[T]]](self.value^)))

    def flatten[T: Movable & Deinitable, //](deinit self) raises OptionalFamily.BindError[Optional[Optional[T]], _Same[Optional[T]]] -> Piped[OptionalFamily.Bound[Optional[Optional[T]], _Same[Optional[T]]]] where Self.Value == Optional[Optional[T]]:
        """Derive flatten through flat_map, preserving the family's semantics."""
        comptime assert Self.Value == Optional[Optional[T]]
        return Piped(OptionalFamily.flat_map(_Same[Optional[T]](), rebind_var[Optional[Optional[T]]](self.value^)))

    def sequence[T: Movable & Deinitable, //, G: Applicative](deinit self) raises OptionalFamily.TraverseError[G, Optional[T], _Same[T]] -> Piped[OptionalFamily.Traversed[G, Optional[T], _Same[T]]] where Self.Value == Optional[T] and OptionalFamily.TargetCompatible[G, Optional[T], _Same[T]]:
        """Derive sequence through traverse, preserving the family's semantics."""
        comptime assert Self.Value == Optional[T]
        return Piped(OptionalFamily.traverse[G](_Same[T](), rebind_var[Optional[T]](self.value^)))

    def par_sequence[T: Movable & Deinitable, //, S: Semigroup = _ListErrors[T]](deinit self) raises Never -> Piped[OptionalFamily.Traversed[ValidationFamily[S], Optional[T], _Same[T]]] where Self.Value == Optional[T] and OptionalFamily.TargetCompatible[ValidationFamily[S], Optional[T], _Same[T]] and _CarrierCompatible[ValidationFamily[S], T]:
        """Derive par_sequence through traverse, preserving the family's semantics."""
        comptime assert Self.Value == Optional[T]
        return Piped(_traverse_as[OptionalFamily, ValidationFamily[S], Optional[T], _Same[T], Never](_Same[T](), rebind_var[Optional[T]](self.value^)))

    def fill[T: Movable & Deinitable, U: Movable & Deinitable, Failure: Movable & Deinitable](deinit self, var value: U) -> Piped[Result[U, Failure]] where Self.Value == Result[T, Failure] and _MapCompatible[ResultFamily[Failure], Result[T, Failure], _Fill[T, U]]:
        """Replace payloads with value, moving it for a single call or copying for repeated calls."""
        comptime assert Self.Value == Result[T, Failure]
        return Piped(ResultFamily[Failure].map(_Fill[T, U](value^), rebind_var[Result[T, Failure]](self.value^)))

    def replace[T: Copyable & Equatable & Deinitable, Failure: Movable & Deinitable](deinit self, var old: T, var new: T) -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure]:
        """Replace equal payloads, moving unmatched values unchanged."""
        comptime assert Self.Value == Result[T, Failure]
        return Piped(ResultFamily[Failure].map(_Replace[T](old^, new^), rebind_var[Result[T, Failure]](self.value^)))

    def void[T: Movable & Deinitable, Failure: Movable & Deinitable](deinit self) -> Piped[Result[NoneType, Failure]] where Self.Value == Result[T, Failure]:
        """Discard payloads while preserving their container shape."""
        comptime assert Self.Value == Result[T, Failure]
        return Piped(ResultFamily[Failure].map(_Fill[T, NoneType](None), rebind_var[Result[T, Failure]](self.value^)))

    def tuple_left[T: Movable & Deinitable, U: Movable & Deinitable, Failure: Movable & Deinitable](deinit self, var value: U) -> Piped[Result[Tuple[U, T], Failure]] where Self.Value == Result[T, Failure] and _MapCompatible[ResultFamily[Failure], Result[T, Failure], _TupleWith[T, U, True]]:
        """Attach value on the left, moving it for a single call or copying for repeated calls."""
        comptime assert Self.Value == Result[T, Failure]
        return Piped(ResultFamily[Failure].map(_TupleWith[T, U, True](value^), rebind_var[Result[T, Failure]](self.value^)))

    def tuple_right[T: Movable & Deinitable, U: Movable & Deinitable, Failure: Movable & Deinitable](deinit self, var value: U) -> Piped[Result[Tuple[T, U], Failure]] where Self.Value == Result[T, Failure] and _MapCompatible[ResultFamily[Failure], Result[T, Failure], _TupleWith[T, U, False]]:
        """Attach value on the right, moving it for a single call or copying for repeated calls."""
        comptime assert Self.Value == Result[T, Failure]
        return Piped(ResultFamily[Failure].map(_TupleWith[T, U, False](value^), rebind_var[Result[T, Failure]](self.value^)))

    def pair_with[P: AnyType, R: Movable & Deinitable, Failure: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[Result[Tuple[downcast[P, Movable & Deinitable], R], Failure]] where Self.Value == Result[downcast[P, Movable & Deinitable], Failure]:
        """Borrow each payload for projection and retain it beside the result."""
        comptime assert Self.Value == Result[downcast[P, Movable & Deinitable], Failure]
        return Piped(ResultFamily[Failure].map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[Result[downcast[P, Movable & Deinitable], Failure]](self.value^)))

    def pair_with[P: AnyType, R: Movable & Deinitable, Failure: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Result[Tuple[downcast[P, Movable & Deinitable], R], Failure]] where Self.Value == Result[downcast[P, Movable & Deinitable], Failure]:
        """Borrow each payload for projection and retain it beside the result."""
        comptime assert Self.Value == Result[downcast[P, Movable & Deinitable], Failure]
        return Piped(ResultFamily[Failure].map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[Result[downcast[P, Movable & Deinitable], Failure]](self.value^)))

    def pair_with[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, Failure: Movable & Deinitable](deinit self, var function: C) raises C.Failure -> Piped[Result[Tuple[T, C.Result], Failure]] where Self.Value == Result[T, Failure] and C.Payload == T and RepeatableBorrow[C]:
        """Borrow each payload for projection and retain it beside the result."""
        comptime assert Self.Value == Result[T, Failure]
        return Piped(ResultFamily[Failure].map(_Observe[T, C, True](function^), rebind_var[Result[T, Failure]](self.value^)))

    def tap_each[P: AnyType, R: Movable & Deinitable, Failure: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[Result[downcast[P, Movable & Deinitable], Failure]] where Self.Value == Result[downcast[P, Movable & Deinitable], Failure]:
        """Borrow each payload for inspection and retain it unchanged."""
        comptime assert Self.Value == Result[downcast[P, Movable & Deinitable], Failure]
        return Piped(ResultFamily[Failure].map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], False](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[Result[downcast[P, Movable & Deinitable], Failure]](self.value^)))

    def tap_each[P: AnyType, R: Movable & Deinitable, Failure: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Result[downcast[P, Movable & Deinitable], Failure]] where Self.Value == Result[downcast[P, Movable & Deinitable], Failure]:
        """Borrow each payload for inspection and retain it unchanged."""
        comptime assert Self.Value == Result[downcast[P, Movable & Deinitable], Failure]
        return Piped(ResultFamily[Failure].map(_Observe[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], False](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[Result[downcast[P, Movable & Deinitable], Failure]](self.value^)))

    def tap_each[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, Failure: Movable & Deinitable](deinit self, var function: C) raises C.Failure -> Piped[Result[T, Failure]] where Self.Value == Result[T, Failure] and C.Payload == T and RepeatableBorrow[C]:
        """Borrow each payload for inspection and retain it unchanged."""
        comptime assert Self.Value == Result[T, Failure]
        return Piped(ResultFamily[Failure].map(_Observe[T, C, False](function^), rebind_var[Result[T, Failure]](self.value^)))

    def flat_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, Failure: Movable & Deinitable, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises ResultFamily[Failure].BindError[Result[A, Failure], _NativeUnaryRef[A, R, Never, F, False, o]] -> Piped[ResultFamily[Failure].Bound[Result[A, Failure], _NativeUnaryRef[A, R, Never, F, False, o]]] where Self.Value == Result[A, Failure]:
        """Apply flat_map through the carrier's Monad capability."""
        comptime assert Self.Value == Result[A, Failure]
        return Piped(ResultFamily[Failure].flat_map(_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), rebind_var[Result[A, Failure]](self.value^)))

    def flat_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, Failure: Movable & Deinitable, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises ResultFamily[Failure].BindError[Result[A, Failure], _NativeUnaryRef[A, R, E, F, True, o]] -> Piped[ResultFamily[Failure].Bound[Result[A, Failure], _NativeUnaryRef[A, R, E, F, True, o]]] where Self.Value == Result[A, Failure]:
        """Apply flat_map through the carrier's Monad capability."""
        comptime assert Self.Value == Result[A, Failure]
        return Piped(ResultFamily[Failure].flat_map(_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), rebind_var[Result[A, Failure]](self.value^)))

    def flat_map[F: UnaryContract & Movable & Deinitable, Failure: Movable & Deinitable, //](deinit self, var function: F) raises ResultFamily[Failure].BindError[Result[F.Arg, Failure], F] -> Piped[ResultFamily[Failure].Bound[Result[F.Arg, Failure], F]] where Self.Value == Result[F.Arg, Failure]:
        """Apply flat_map through the carrier's Monad capability."""
        comptime assert Self.Value == Result[F.Arg, Failure]
        return Piped(ResultFamily[Failure].flat_map(function^, rebind_var[Result[F.Arg, Failure]](self.value^)))

    def flat_map[F: _UnaryViewable, o: ImmOrigin, Failure: Movable & Deinitable, //](deinit self, ref[o] function: F) raises ResultFamily[Failure].BindError[Result[F._View[o].Arg, Failure], F._View[o]] -> Piped[ResultFamily[Failure].Bound[Result[F._View[o].Arg, Failure], F._View[o]]] where Self.Value == Result[F._View[o].Arg, Failure]:
        """Apply flat_map through the carrier's Monad capability."""
        comptime assert Self.Value == Result[F._View[o].Arg, Failure]
        return Piped(ResultFamily[Failure].flat_map(function._unary_view(), rebind_var[Result[F._View[o].Arg, Failure]](self.value^)))

    def traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, Failure: Movable & Deinitable, //, G: Applicative, F: _Unary[A, R]](deinit self, ref[o] function: F) raises ResultFamily[Failure].TraverseError[G, Result[A, Failure], _NativeUnaryRef[A, R, Never, F, False, o]] -> Piped[ResultFamily[Failure].Traversed[G, Result[A, Failure], _NativeUnaryRef[A, R, Never, F, False, o]]] where Self.Value == Result[A, Failure] and ResultFamily[Failure].TargetCompatible[G, Result[A, Failure], _NativeUnaryRef[A, R, Never, F, False, o]]:
        """Apply traverse through the carrier's Traversable capability."""
        comptime assert Self.Value == Result[A, Failure]
        return Piped(ResultFamily[Failure].traverse[G](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), rebind_var[Result[A, Failure]](self.value^)))

    def traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, Failure: Movable & Deinitable, //, G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises ResultFamily[Failure].TraverseError[G, Result[A, Failure], _NativeUnaryRef[A, R, E, F, True, o]] -> Piped[ResultFamily[Failure].Traversed[G, Result[A, Failure], _NativeUnaryRef[A, R, E, F, True, o]]] where Self.Value == Result[A, Failure] and ResultFamily[Failure].TargetCompatible[G, Result[A, Failure], _NativeUnaryRef[A, R, E, F, True, o]]:
        """Apply traverse through the carrier's Traversable capability."""
        comptime assert Self.Value == Result[A, Failure]
        return Piped(ResultFamily[Failure].traverse[G](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), rebind_var[Result[A, Failure]](self.value^)))

    def traverse[F: UnaryContract & Movable & Deinitable, Failure: Movable & Deinitable, //, G: Applicative](deinit self, var function: F) raises ResultFamily[Failure].TraverseError[G, Result[F.Arg, Failure], F] -> Piped[ResultFamily[Failure].Traversed[G, Result[F.Arg, Failure], F]] where Self.Value == Result[F.Arg, Failure] and ResultFamily[Failure].TargetCompatible[G, Result[F.Arg, Failure], F]:
        """Apply traverse through the carrier's Traversable capability."""
        comptime assert Self.Value == Result[F.Arg, Failure]
        return Piped(ResultFamily[Failure].traverse[G](function^, rebind_var[Result[F.Arg, Failure]](self.value^)))

    def traverse[F: _UnaryViewable, o: ImmOrigin, Failure: Movable & Deinitable, //, G: Applicative](deinit self, ref[o] function: F) raises ResultFamily[Failure].TraverseError[G, Result[F._View[o].Arg, Failure], F._View[o]] -> Piped[ResultFamily[Failure].Traversed[G, Result[F._View[o].Arg, Failure], F._View[o]]] where Self.Value == Result[F._View[o].Arg, Failure] and ResultFamily[Failure].TargetCompatible[G, Result[F._View[o].Arg, Failure], F._View[o]]:
        """Apply traverse through the carrier's Traversable capability."""
        comptime assert Self.Value == Result[F._View[o].Arg, Failure]
        return Piped(ResultFamily[Failure].traverse[G](function._unary_view(), rebind_var[Result[F._View[o].Arg, Failure]](self.value^)))

    def par_traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, Failure: Movable & Deinitable, F: _Unary[A, R], //, S: Semigroup = _ListErrors[R]](deinit self, ref[o] function: F) raises ResultFamily[Failure].TraverseError[ValidationFamily[S], Result[A, Failure], _NativeUnaryRef[A, R, Never, F, False, o]] -> Piped[ResultFamily[Failure].Traversed[ValidationFamily[S], Result[A, Failure], _NativeUnaryRef[A, R, Never, F, False, o]]] where Self.Value == Result[A, Failure] and ResultFamily[Failure].TargetCompatible[ValidationFamily[S], Result[A, Failure], _NativeUnaryRef[A, R, Never, F, False, o]] and _CarrierCompatible[ValidationFamily[S], R]:
        """Apply par_traverse through the carrier's Traversable capability."""
        comptime assert Self.Value == Result[A, Failure]
        return Piped(ResultFamily[Failure].traverse[ValidationFamily[S]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), rebind_var[Result[A, Failure]](self.value^)))

    def par_traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, Failure: Movable & Deinitable, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], //, S: Semigroup = _ListErrors[R]](deinit self, ref[o] function: F) raises ResultFamily[Failure].TraverseError[ValidationFamily[S], Result[A, Failure], _NativeUnaryRef[A, R, E, F, True, o]] -> Piped[ResultFamily[Failure].Traversed[ValidationFamily[S], Result[A, Failure], _NativeUnaryRef[A, R, E, F, True, o]]] where Self.Value == Result[A, Failure] and ResultFamily[Failure].TargetCompatible[ValidationFamily[S], Result[A, Failure], _NativeUnaryRef[A, R, E, F, True, o]] and _CarrierCompatible[ValidationFamily[S], R]:
        """Apply par_traverse through the carrier's Traversable capability."""
        comptime assert Self.Value == Result[A, Failure]
        return Piped(ResultFamily[Failure].traverse[ValidationFamily[S]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), rebind_var[Result[A, Failure]](self.value^)))

    def par_traverse[F: UnaryContract & Movable & Deinitable, Failure: Movable & Deinitable, //, S: Semigroup = _ListErrors[F.Out]](deinit self, var function: F) raises ResultFamily[Failure].TraverseError[ValidationFamily[S], Result[F.Arg, Failure], F] -> Piped[ResultFamily[Failure].Traversed[ValidationFamily[S], Result[F.Arg, Failure], F]] where Self.Value == Result[F.Arg, Failure] and ResultFamily[Failure].TargetCompatible[ValidationFamily[S], Result[F.Arg, Failure], F] and _CarrierCompatible[ValidationFamily[S], F.Out]:
        """Apply par_traverse through the carrier's Traversable capability."""
        comptime assert Self.Value == Result[F.Arg, Failure]
        return Piped(ResultFamily[Failure].traverse[ValidationFamily[S]](function^, rebind_var[Result[F.Arg, Failure]](self.value^)))

    def par_traverse[F: _UnaryViewable, o: ImmOrigin, Failure: Movable & Deinitable, //, S: Semigroup = _ListErrors[F._View[o].Out]](deinit self, ref[o] function: F) raises ResultFamily[Failure].TraverseError[ValidationFamily[S], Result[F._View[o].Arg, Failure], F._View[o]] -> Piped[ResultFamily[Failure].Traversed[ValidationFamily[S], Result[F._View[o].Arg, Failure], F._View[o]]] where Self.Value == Result[F._View[o].Arg, Failure] and ResultFamily[Failure].TargetCompatible[ValidationFamily[S], Result[F._View[o].Arg, Failure], F._View[o]] and _CarrierCompatible[ValidationFamily[S], F._View[o].Out]:
        """Apply par_traverse through the carrier's Traversable capability."""
        comptime assert Self.Value == Result[F._View[o].Arg, Failure]
        return Piped(ResultFamily[Failure].traverse[ValidationFamily[S]](function._unary_view(), rebind_var[Result[F._View[o].Arg, Failure]](self.value^)))

    def flatten[T: Movable & Deinitable, Failure: Movable & Deinitable, //](deinit self) raises ResultFamily[Failure].BindError[Result[Result[T, Failure], Failure], _Same[Result[T, Failure]]] -> Piped[ResultFamily[Failure].Bound[Result[Result[T, Failure], Failure], _Same[Result[T, Failure]]]] where Self.Value == Result[Result[T, Failure], Failure]:
        """Derive flatten through flat_map, preserving the family's semantics."""
        comptime assert Self.Value == Result[Result[T, Failure], Failure]
        return Piped(ResultFamily[Failure].flat_map(_Same[Result[T, Failure]](), rebind_var[Result[Result[T, Failure], Failure]](self.value^)))

    def sequence[T: Movable & Deinitable, Failure: Movable & Deinitable, //, G: Applicative](deinit self) raises ResultFamily[Failure].TraverseError[G, Result[T, Failure], _Same[T]] -> Piped[ResultFamily[Failure].Traversed[G, Result[T, Failure], _Same[T]]] where Self.Value == Result[T, Failure] and ResultFamily[Failure].TargetCompatible[G, Result[T, Failure], _Same[T]]:
        """Derive sequence through traverse, preserving the family's semantics."""
        comptime assert Self.Value == Result[T, Failure]
        return Piped(ResultFamily[Failure].traverse[G](_Same[T](), rebind_var[Result[T, Failure]](self.value^)))

    def par_sequence[T: Movable & Deinitable, Failure: Movable & Deinitable, //, S: Semigroup = _ListErrors[T]](deinit self) raises Never -> Piped[ResultFamily[Failure].Traversed[ValidationFamily[S], Result[T, Failure], _Same[T]]] where Self.Value == Result[T, Failure] and ResultFamily[Failure].TargetCompatible[ValidationFamily[S], Result[T, Failure], _Same[T]] and _CarrierCompatible[ValidationFamily[S], T]:
        """Derive par_sequence through traverse, preserving the family's semantics."""
        comptime assert Self.Value == Result[T, Failure]
        return Piped(_traverse_as[ResultFamily[Failure], ValidationFamily[S], Result[T, Failure], _Same[T], Never](_Same[T](), rebind_var[Result[T, Failure]](self.value^)))

    def find_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> Piped[R] where Self.Value == List[A]:
        """Return the first present transformed result, stopping without another pull.

        Parameters:
            A: The callback input type, including its native origins.
            R: The native callback result type.
            o: The origin of the borrowed native callback.
            F: The callback type, retaining its receiver, captures and error contract.

        Args:
            function: The callback, borrowed in place; calls follow the operation's evaluation order.

        Returns:
            The first present Optional result, or absence; no later element is pulled.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        comptime assert Self.Value == List[A]
        return Piped(_run_terminal(_FindMapRun[_NativeUnaryRef[A, R, Never, F, False, o]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[List[A]](self.value^)))

    def find_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> Piped[R] where Self.Value == List[A]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == List[A]
        return Piped(_run_terminal(_FindMapRun[_NativeUnaryRef[A, R, E, F, True, o]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[List[A]](self.value^)))

    def find_map[F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises F.Error -> Piped[F.Out] where Self.Value == List[F.Arg]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == List[F.Arg]
        return Piped(_run_terminal(_FindMapRun[F](function^), rebind_var[List[F.Arg]](self.value^)))

    def find_map[F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises F._View[o].Error -> Piped[F._View[o].Out] where Self.Value == List[F._View[o].Arg]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == List[F._View[o].Arg]
        return Piped(_run_terminal(_FindMapRun[F._View[o]](function._unary_view()), rebind_var[List[F._View[o].Arg]](self.value^)))

    def fold_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, M: Monoid, F: _Unary[A, R]](deinit self, ref[o] function: F) raises _CommonError[Never, M.Error] -> Piped[M.Value] where Self.Value == List[A]:
        """Project and combine in order with a monoid; empty input returns its identity.

        Parameters:
            A: The callback input type, including its native origins.
            R: The native callback result type.
            o: The origin of the borrowed native callback.
            M: The Monoid providing the result type, identity and ordered combination.
            F: The callback type, retaining its receiver, captures and error contract.

        Args:
            function: The callback, borrowed in place; calls follow the operation's evaluation order.

        Returns:
            The projected values combined in order, or the monoid identity on empty input.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        comptime assert Self.Value == List[A]
        return Piped(_run_terminal(_FoldMapRun[_NativeUnaryRef[A, R, Never, F, False, o], M, _CommonError[Never, M.Error]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[List[A]](self.value^)))

    def fold_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, M: Monoid, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises _CommonError[E, M.Error] -> Piped[M.Value] where Self.Value == List[A]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == List[A]
        return Piped(_run_terminal(_FoldMapRun[_NativeUnaryRef[A, R, E, F, True, o], M, _CommonError[E, M.Error]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[List[A]](self.value^)))

    def fold_map[F: UnaryContract & Movable & Deinitable, //, M: Monoid](deinit self, var function: F) raises _CommonError[F.Error, M.Error] -> Piped[M.Value] where Self.Value == List[F.Arg]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == List[F.Arg]
        return Piped(_run_terminal(_FoldMapRun[F, M, _CommonError[F.Error, M.Error]](function^), rebind_var[List[F.Arg]](self.value^)))

    def fold_map[F: _UnaryViewable, o: ImmOrigin, //, M: Monoid](deinit self, ref[o] function: F) raises _CommonError[F._View[o].Error, M.Error] -> Piped[M.Value] where Self.Value == List[F._View[o].Arg]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == List[F._View[o].Arg]
        return Piped(_run_terminal(_FoldMapRun[F._View[o], M, _CommonError[F._View[o].Error, M.Error]](function._unary_view()), rebind_var[List[F._View[o].Arg]](self.value^)))

    def combine_all[M: Monoid](deinit self) raises _CommonError[Never, M.Error] -> Piped[M.Value] where Self.Value == List[M.Value]:
        """Combine in order with a monoid; empty input returns its identity.

        Parameters:
            M: The Monoid providing the result type, identity and ordered combination.

        Returns:
            The values combined in order, or the monoid identity on empty input.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        comptime assert Self.Value == List[M.Value]
        return Piped(_run_terminal(_FoldMapRun[_Same[M.Value], M, _CommonError[Never, M.Error]](_Same[M.Value]()), rebind_var[List[M.Value]](self.value^)))

    def min_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == List[downcast[P, Movable & Deinitable]] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first.

        Parameters:
            P: The borrowed callback payload type, including its native origins.
            R: The native callback result type.
            o: The origin of the borrowed native callback.
            F: The callback type, retaining its receiver, captures and error contract.

        Args:
            function: The callback, borrowed in place; calls follow the operation's evaluation order.

        Returns:
            An Optional containing the element with the smallest key; ties retain the first element.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        comptime assert Self.Value == List[downcast[P, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[List[downcast[P, Movable & Deinitable]]](self.value^)))

    def min_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == List[downcast[P, Movable & Deinitable]] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == List[downcast[P, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[List[downcast[P, Movable & Deinitable]]](self.value^)))

    def min_by[C: BorrowCallContract & Movable & Deinitable, //](deinit self, var function: C) raises C.Failure -> Piped[Optional[downcast[C.Payload, Movable & Deinitable]]] where Self.Value == List[downcast[C.Payload, Movable & Deinitable]] and conforms_to(C.Result, Comparable & Movable & Deinitable) and RepeatableBorrow[C]:
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == List[downcast[C.Payload, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[C.Payload, Movable & Deinitable], C, True](function^), rebind_var[List[downcast[C.Payload, Movable & Deinitable]]](self.value^)))

    def min_by[C: _BorrowViewable, o: ImmOrigin, //](deinit self, ref[o] function: C) raises C._BorrowView[o].Failure -> Piped[Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]] where Self.Value == List[downcast[C._BorrowView[o].Payload, Movable & Deinitable]] and conforms_to(C._BorrowView[o].Result, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == List[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[C._BorrowView[o].Payload, Movable & Deinitable], C._BorrowView[o], True](function._borrow_view()), rebind_var[List[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]](self.value^)))

    def max_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == List[downcast[P, Movable & Deinitable]] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first.

        Parameters:
            P: The borrowed callback payload type, including its native origins.
            R: The native callback result type.
            o: The origin of the borrowed native callback.
            F: The callback type, retaining its receiver, captures and error contract.

        Args:
            function: The callback, borrowed in place; calls follow the operation's evaluation order.

        Returns:
            An Optional containing the element with the largest key; ties retain the first element.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        comptime assert Self.Value == List[downcast[P, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], False](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[List[downcast[P, Movable & Deinitable]]](self.value^)))

    def max_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == List[downcast[P, Movable & Deinitable]] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == List[downcast[P, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], False](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[List[downcast[P, Movable & Deinitable]]](self.value^)))

    def max_by[C: BorrowCallContract & Movable & Deinitable, //](deinit self, var function: C) raises C.Failure -> Piped[Optional[downcast[C.Payload, Movable & Deinitable]]] where Self.Value == List[downcast[C.Payload, Movable & Deinitable]] and conforms_to(C.Result, Comparable & Movable & Deinitable) and RepeatableBorrow[C]:
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == List[downcast[C.Payload, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[C.Payload, Movable & Deinitable], C, False](function^), rebind_var[List[downcast[C.Payload, Movable & Deinitable]]](self.value^)))

    def max_by[C: _BorrowViewable, o: ImmOrigin, //](deinit self, ref[o] function: C) raises C._BorrowView[o].Failure -> Piped[Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]] where Self.Value == List[downcast[C._BorrowView[o].Payload, Movable & Deinitable]] and conforms_to(C._BorrowView[o].Result, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == List[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[C._BorrowView[o].Payload, Movable & Deinitable], C._BorrowView[o], False](function._borrow_view()), rebind_var[List[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]](self.value^)))

    def sum(deinit self) raises Never -> Piped[Int] where Self.Value == List[Int]:
        """Add in order from zero, preserving the numeric type and SIMD lanes.

        Returns:
            The ordered sum from zero, preserving the numeric type and SIMD lanes.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        comptime assert Self.Value == List[Int]
        return Piped(_run_terminal(_FoldMapRun[_Same[Int], _IntSum, Never](_Same[Int]()), rebind_var[List[Int]](self.value^)))

    def sum[dtype: DType, size: SIMDLength, //](deinit self) raises Never -> Piped[SIMD[dtype, size]] where Self.Value == List[SIMD[dtype, size]]:
        """Add in order from zero, preserving the numeric type and SIMD lanes."""
        comptime assert Self.Value == List[SIMD[dtype, size]]
        return Piped(_run_terminal(_FoldMapRun[_Same[SIMD[dtype, size]], _SIMDSum[dtype, size], Never](_Same[SIMD[dtype, size]]()), rebind_var[List[SIMD[dtype, size]]](self.value^)))

    def sum_by[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> Piped[Int] where Self.Value == List[A] and R == Int:
        """Project and add in one pass from zero, without an intermediate collection.

        Parameters:
            A: The callback input type, including its native origins.
            R: The native callback result type.
            o: The origin of the borrowed native callback.
            F: The callback type, retaining its receiver, captures and error contract.

        Args:
            function: The callback, borrowed in place; calls follow the operation's evaluation order.

        Returns:
            The ordered sum of projections from zero, without a mapped intermediate collection.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        comptime assert Self.Value == List[A]
        return Piped(_run_terminal(_FoldMapRun[_NativeUnaryRef[A, R, Never, F, False, o], _IntSum, Never](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[List[A]](self.value^)))

    def sum_by[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Int] where Self.Value == List[A] and R == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == List[A]
        return Piped(_run_terminal(_FoldMapRun[_NativeUnaryRef[A, R, E, F, True, o], _IntSum, E](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[List[A]](self.value^)))

    def sum_by[F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises F.Error -> Piped[Int] where Self.Value == List[F.Arg] and F.Out == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == List[F.Arg]
        return Piped(_run_terminal(_FoldMapRun[F, _IntSum, F.Error](function^), rebind_var[List[F.Arg]](self.value^)))

    def sum_by[F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises F._View[o].Error -> Piped[Int] where Self.Value == List[F._View[o].Arg] and F._View[o].Out == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == List[F._View[o].Arg]
        return Piped(_run_terminal(_FoldMapRun[F._View[o], _IntSum, F._View[o].Error](function._unary_view()), rebind_var[List[F._View[o].Arg]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> Piped[SIMD[dtype, size]] where Self.Value == List[A] and R == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == List[A]
        return Piped(_run_terminal(_FoldMapRun[_NativeUnaryRef[A, R, Never, F, False, o], _SIMDSum[dtype, size], Never](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[List[A]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> Piped[SIMD[dtype, size]] where Self.Value == List[A] and R == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == List[A]
        return Piped(_run_terminal(_FoldMapRun[_NativeUnaryRef[A, R, E, F, True, o], _SIMDSum[dtype, size], E](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[List[A]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises F.Error -> Piped[SIMD[dtype, size]] where Self.Value == List[F.Arg] and F.Out == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == List[F.Arg]
        return Piped(_run_terminal(_FoldMapRun[F, _SIMDSum[dtype, size], F.Error](function^), rebind_var[List[F.Arg]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises F._View[o].Error -> Piped[SIMD[dtype, size]] where Self.Value == List[F._View[o].Arg] and F._View[o].Out == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == List[F._View[o].Arg]
        return Piped(_run_terminal(_FoldMapRun[F._View[o], _SIMDSum[dtype, size], F._View[o].Error](function._unary_view()), rebind_var[List[F._View[o].Arg]](self.value^)))


    def find_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> Piped[R] where Self.Value == Array[A, N]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == Array[A, N]
        return Piped(_array_terminal(_FindMapRun[_NativeUnaryRef[A, R, Never, F, False, o]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[Array[A, N]](self.value^)))

    def find_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> Piped[R] where Self.Value == Array[A, N]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == Array[A, N]
        return Piped(_array_terminal(_FindMapRun[_NativeUnaryRef[A, R, E, F, True, o]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[Array[A, N]](self.value^)))

    def find_map[F: UnaryContract & Movable & Deinitable, N: Int, //](deinit self, var function: F) raises F.Error -> Piped[F.Out] where Self.Value == Array[F.Arg, N]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == Array[F.Arg, N]
        return Piped(_array_terminal(_FindMapRun[F](function^), rebind_var[Array[F.Arg, N]](self.value^)))

    def find_map[F: _UnaryViewable, o: ImmOrigin, N: Int, //](deinit self, ref[o] function: F) raises F._View[o].Error -> Piped[F._View[o].Out] where Self.Value == Array[F._View[o].Arg, N]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == Array[F._View[o].Arg, N]
        return Piped(_array_terminal(_FindMapRun[F._View[o]](function._unary_view()), rebind_var[Array[F._View[o].Arg, N]](self.value^)))

    def fold_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, M: Monoid, F: _Unary[A, R]](deinit self, ref[o] function: F) raises _CommonError[Never, M.Error] -> Piped[M.Value] where Self.Value == Array[A, N]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == Array[A, N]
        return Piped(_array_terminal(_FoldMapRun[_NativeUnaryRef[A, R, Never, F, False, o], M, _CommonError[Never, M.Error]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[Array[A, N]](self.value^)))

    def fold_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, M: Monoid, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises _CommonError[E, M.Error] -> Piped[M.Value] where Self.Value == Array[A, N]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == Array[A, N]
        return Piped(_array_terminal(_FoldMapRun[_NativeUnaryRef[A, R, E, F, True, o], M, _CommonError[E, M.Error]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[Array[A, N]](self.value^)))

    def fold_map[F: UnaryContract & Movable & Deinitable, N: Int, //, M: Monoid](deinit self, var function: F) raises _CommonError[F.Error, M.Error] -> Piped[M.Value] where Self.Value == Array[F.Arg, N]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == Array[F.Arg, N]
        return Piped(_array_terminal(_FoldMapRun[F, M, _CommonError[F.Error, M.Error]](function^), rebind_var[Array[F.Arg, N]](self.value^)))

    def fold_map[F: _UnaryViewable, o: ImmOrigin, N: Int, //, M: Monoid](deinit self, ref[o] function: F) raises _CommonError[F._View[o].Error, M.Error] -> Piped[M.Value] where Self.Value == Array[F._View[o].Arg, N]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == Array[F._View[o].Arg, N]
        return Piped(_array_terminal(_FoldMapRun[F._View[o], M, _CommonError[F._View[o].Error, M.Error]](function._unary_view()), rebind_var[Array[F._View[o].Arg, N]](self.value^)))

    def combine_all[N: Int, //, M: Monoid](deinit self) raises _CommonError[Never, M.Error] -> Piped[M.Value] where Self.Value == Array[M.Value, N]:
        """Combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == Array[M.Value, N]
        return Piped(_array_terminal(_FoldMapRun[_Same[M.Value], M, _CommonError[Never, M.Error]](_Same[M.Value]()), rebind_var[Array[M.Value, N]](self.value^)))

    def min_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == Array[downcast[P, Movable & Deinitable], N] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Array[downcast[P, Movable & Deinitable], N]
        return Piped(_array_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[Array[downcast[P, Movable & Deinitable], N]](self.value^)))

    def min_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == Array[downcast[P, Movable & Deinitable], N] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Array[downcast[P, Movable & Deinitable], N]
        return Piped(_array_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[Array[downcast[P, Movable & Deinitable], N]](self.value^)))

    def min_by[C: BorrowCallContract & Movable & Deinitable, N: Int, //](deinit self, var function: C) raises C.Failure -> Piped[Optional[downcast[C.Payload, Movable & Deinitable]]] where Self.Value == Array[downcast[C.Payload, Movable & Deinitable], N] and conforms_to(C.Result, Comparable & Movable & Deinitable) and RepeatableBorrow[C]:
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Array[downcast[C.Payload, Movable & Deinitable], N]
        return Piped(_array_terminal(_ExtremumRun[downcast[C.Payload, Movable & Deinitable], C, True](function^), rebind_var[Array[downcast[C.Payload, Movable & Deinitable], N]](self.value^)))

    def min_by[C: _BorrowViewable, o: ImmOrigin, N: Int, //](deinit self, ref[o] function: C) raises C._BorrowView[o].Failure -> Piped[Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]] where Self.Value == Array[downcast[C._BorrowView[o].Payload, Movable & Deinitable], N] and conforms_to(C._BorrowView[o].Result, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Array[downcast[C._BorrowView[o].Payload, Movable & Deinitable], N]
        return Piped(_array_terminal(_ExtremumRun[downcast[C._BorrowView[o].Payload, Movable & Deinitable], C._BorrowView[o], True](function._borrow_view()), rebind_var[Array[downcast[C._BorrowView[o].Payload, Movable & Deinitable], N]](self.value^)))

    def max_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == Array[downcast[P, Movable & Deinitable], N] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Array[downcast[P, Movable & Deinitable], N]
        return Piped(_array_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], False](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[Array[downcast[P, Movable & Deinitable], N]](self.value^)))

    def max_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == Array[downcast[P, Movable & Deinitable], N] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Array[downcast[P, Movable & Deinitable], N]
        return Piped(_array_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], False](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[Array[downcast[P, Movable & Deinitable], N]](self.value^)))

    def max_by[C: BorrowCallContract & Movable & Deinitable, N: Int, //](deinit self, var function: C) raises C.Failure -> Piped[Optional[downcast[C.Payload, Movable & Deinitable]]] where Self.Value == Array[downcast[C.Payload, Movable & Deinitable], N] and conforms_to(C.Result, Comparable & Movable & Deinitable) and RepeatableBorrow[C]:
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Array[downcast[C.Payload, Movable & Deinitable], N]
        return Piped(_array_terminal(_ExtremumRun[downcast[C.Payload, Movable & Deinitable], C, False](function^), rebind_var[Array[downcast[C.Payload, Movable & Deinitable], N]](self.value^)))

    def max_by[C: _BorrowViewable, o: ImmOrigin, N: Int, //](deinit self, ref[o] function: C) raises C._BorrowView[o].Failure -> Piped[Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]] where Self.Value == Array[downcast[C._BorrowView[o].Payload, Movable & Deinitable], N] and conforms_to(C._BorrowView[o].Result, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Array[downcast[C._BorrowView[o].Payload, Movable & Deinitable], N]
        return Piped(_array_terminal(_ExtremumRun[downcast[C._BorrowView[o].Payload, Movable & Deinitable], C._BorrowView[o], False](function._borrow_view()), rebind_var[Array[downcast[C._BorrowView[o].Payload, Movable & Deinitable], N]](self.value^)))

    def sum[N: Int, //](deinit self) raises Never -> Piped[Int] where Self.Value == Array[Int, N]:
        """Add in order from zero, preserving the numeric type and SIMD lanes."""
        comptime assert Self.Value == Array[Int, N]
        return Piped(_array_terminal(_FoldMapRun[_Same[Int], _IntSum, Never](_Same[Int]()), rebind_var[Array[Int, N]](self.value^)))

    def sum[dtype: DType, size: SIMDLength, N: Int, //](deinit self) raises Never -> Piped[SIMD[dtype, size]] where Self.Value == Array[SIMD[dtype, size], N]:
        """Add in order from zero, preserving the numeric type and SIMD lanes."""
        comptime assert Self.Value == Array[SIMD[dtype, size], N]
        return Piped(_array_terminal(_FoldMapRun[_Same[SIMD[dtype, size]], _SIMDSum[dtype, size], Never](_Same[SIMD[dtype, size]]()), rebind_var[Array[SIMD[dtype, size], N]](self.value^)))

    def sum_by[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> Piped[Int] where Self.Value == Array[A, N] and R == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Array[A, N]
        return Piped(_array_terminal(_FoldMapRun[_NativeUnaryRef[A, R, Never, F, False, o], _IntSum, Never](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[Array[A, N]](self.value^)))

    def sum_by[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Int] where Self.Value == Array[A, N] and R == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Array[A, N]
        return Piped(_array_terminal(_FoldMapRun[_NativeUnaryRef[A, R, E, F, True, o], _IntSum, E](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[Array[A, N]](self.value^)))

    def sum_by[F: UnaryContract & Movable & Deinitable, N: Int, //](deinit self, var function: F) raises F.Error -> Piped[Int] where Self.Value == Array[F.Arg, N] and F.Out == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Array[F.Arg, N]
        return Piped(_array_terminal(_FoldMapRun[F, _IntSum, F.Error](function^), rebind_var[Array[F.Arg, N]](self.value^)))

    def sum_by[F: _UnaryViewable, o: ImmOrigin, N: Int, //](deinit self, ref[o] function: F) raises F._View[o].Error -> Piped[Int] where Self.Value == Array[F._View[o].Arg, N] and F._View[o].Out == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Array[F._View[o].Arg, N]
        return Piped(_array_terminal(_FoldMapRun[F._View[o], _IntSum, F._View[o].Error](function._unary_view()), rebind_var[Array[F._View[o].Arg, N]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> Piped[SIMD[dtype, size]] where Self.Value == Array[A, N] and R == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Array[A, N]
        return Piped(_array_terminal(_FoldMapRun[_NativeUnaryRef[A, R, Never, F, False, o], _SIMDSum[dtype, size], Never](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[Array[A, N]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> Piped[SIMD[dtype, size]] where Self.Value == Array[A, N] and R == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Array[A, N]
        return Piped(_array_terminal(_FoldMapRun[_NativeUnaryRef[A, R, E, F, True, o], _SIMDSum[dtype, size], E](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[Array[A, N]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, F: UnaryContract & Movable & Deinitable, N: Int, //](deinit self, var function: F) raises F.Error -> Piped[SIMD[dtype, size]] where Self.Value == Array[F.Arg, N] and F.Out == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Array[F.Arg, N]
        return Piped(_array_terminal(_FoldMapRun[F, _SIMDSum[dtype, size], F.Error](function^), rebind_var[Array[F.Arg, N]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, F: _UnaryViewable, o: ImmOrigin, N: Int, //](deinit self, ref[o] function: F) raises F._View[o].Error -> Piped[SIMD[dtype, size]] where Self.Value == Array[F._View[o].Arg, N] and F._View[o].Out == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Array[F._View[o].Arg, N]
        return Piped(_array_terminal(_FoldMapRun[F._View[o], _SIMDSum[dtype, size], F._View[o].Error](function._unary_view()), rebind_var[Array[F._View[o].Arg, N]](self.value^)))


    def find_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> Piped[R] where Self.Value == Deque[A]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == Deque[A]
        return Piped(_run_terminal(_FindMapRun[_NativeUnaryRef[A, R, Never, F, False, o]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[Deque[A]](self.value^)))

    def find_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> Piped[R] where Self.Value == Deque[A]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == Deque[A]
        return Piped(_run_terminal(_FindMapRun[_NativeUnaryRef[A, R, E, F, True, o]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[Deque[A]](self.value^)))

    def find_map[F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises F.Error -> Piped[F.Out] where Self.Value == Deque[F.Arg]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == Deque[F.Arg]
        return Piped(_run_terminal(_FindMapRun[F](function^), rebind_var[Deque[F.Arg]](self.value^)))

    def find_map[F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises F._View[o].Error -> Piped[F._View[o].Out] where Self.Value == Deque[F._View[o].Arg]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == Deque[F._View[o].Arg]
        return Piped(_run_terminal(_FindMapRun[F._View[o]](function._unary_view()), rebind_var[Deque[F._View[o].Arg]](self.value^)))

    def fold_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, M: Monoid, F: _Unary[A, R]](deinit self, ref[o] function: F) raises _CommonError[Never, M.Error] -> Piped[M.Value] where Self.Value == Deque[A]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == Deque[A]
        return Piped(_run_terminal(_FoldMapRun[_NativeUnaryRef[A, R, Never, F, False, o], M, _CommonError[Never, M.Error]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[Deque[A]](self.value^)))

    def fold_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, M: Monoid, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises _CommonError[E, M.Error] -> Piped[M.Value] where Self.Value == Deque[A]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == Deque[A]
        return Piped(_run_terminal(_FoldMapRun[_NativeUnaryRef[A, R, E, F, True, o], M, _CommonError[E, M.Error]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[Deque[A]](self.value^)))

    def fold_map[F: UnaryContract & Movable & Deinitable, //, M: Monoid](deinit self, var function: F) raises _CommonError[F.Error, M.Error] -> Piped[M.Value] where Self.Value == Deque[F.Arg]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == Deque[F.Arg]
        return Piped(_run_terminal(_FoldMapRun[F, M, _CommonError[F.Error, M.Error]](function^), rebind_var[Deque[F.Arg]](self.value^)))

    def fold_map[F: _UnaryViewable, o: ImmOrigin, //, M: Monoid](deinit self, ref[o] function: F) raises _CommonError[F._View[o].Error, M.Error] -> Piped[M.Value] where Self.Value == Deque[F._View[o].Arg]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == Deque[F._View[o].Arg]
        return Piped(_run_terminal(_FoldMapRun[F._View[o], M, _CommonError[F._View[o].Error, M.Error]](function._unary_view()), rebind_var[Deque[F._View[o].Arg]](self.value^)))

    def combine_all[M: Monoid](deinit self) raises _CommonError[Never, M.Error] -> Piped[M.Value] where Self.Value == Deque[M.Value]:
        """Combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == Deque[M.Value]
        return Piped(_run_terminal(_FoldMapRun[_Same[M.Value], M, _CommonError[Never, M.Error]](_Same[M.Value]()), rebind_var[Deque[M.Value]](self.value^)))

    def min_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == Deque[downcast[P, Movable & Deinitable]] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Deque[downcast[P, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[Deque[downcast[P, Movable & Deinitable]]](self.value^)))

    def min_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == Deque[downcast[P, Movable & Deinitable]] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Deque[downcast[P, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[Deque[downcast[P, Movable & Deinitable]]](self.value^)))

    def min_by[C: BorrowCallContract & Movable & Deinitable, //](deinit self, var function: C) raises C.Failure -> Piped[Optional[downcast[C.Payload, Movable & Deinitable]]] where Self.Value == Deque[downcast[C.Payload, Movable & Deinitable]] and conforms_to(C.Result, Comparable & Movable & Deinitable) and RepeatableBorrow[C]:
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Deque[downcast[C.Payload, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[C.Payload, Movable & Deinitable], C, True](function^), rebind_var[Deque[downcast[C.Payload, Movable & Deinitable]]](self.value^)))

    def min_by[C: _BorrowViewable, o: ImmOrigin, //](deinit self, ref[o] function: C) raises C._BorrowView[o].Failure -> Piped[Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]] where Self.Value == Deque[downcast[C._BorrowView[o].Payload, Movable & Deinitable]] and conforms_to(C._BorrowView[o].Result, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Deque[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[C._BorrowView[o].Payload, Movable & Deinitable], C._BorrowView[o], True](function._borrow_view()), rebind_var[Deque[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]](self.value^)))

    def max_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == Deque[downcast[P, Movable & Deinitable]] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Deque[downcast[P, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], False](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[Deque[downcast[P, Movable & Deinitable]]](self.value^)))

    def max_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == Deque[downcast[P, Movable & Deinitable]] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Deque[downcast[P, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], False](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[Deque[downcast[P, Movable & Deinitable]]](self.value^)))

    def max_by[C: BorrowCallContract & Movable & Deinitable, //](deinit self, var function: C) raises C.Failure -> Piped[Optional[downcast[C.Payload, Movable & Deinitable]]] where Self.Value == Deque[downcast[C.Payload, Movable & Deinitable]] and conforms_to(C.Result, Comparable & Movable & Deinitable) and RepeatableBorrow[C]:
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Deque[downcast[C.Payload, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[C.Payload, Movable & Deinitable], C, False](function^), rebind_var[Deque[downcast[C.Payload, Movable & Deinitable]]](self.value^)))

    def max_by[C: _BorrowViewable, o: ImmOrigin, //](deinit self, ref[o] function: C) raises C._BorrowView[o].Failure -> Piped[Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]] where Self.Value == Deque[downcast[C._BorrowView[o].Payload, Movable & Deinitable]] and conforms_to(C._BorrowView[o].Result, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Deque[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[C._BorrowView[o].Payload, Movable & Deinitable], C._BorrowView[o], False](function._borrow_view()), rebind_var[Deque[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]](self.value^)))

    def sum(deinit self) raises Never -> Piped[Int] where Self.Value == Deque[Int]:
        """Add in order from zero, preserving the numeric type and SIMD lanes."""
        comptime assert Self.Value == Deque[Int]
        return Piped(_run_terminal(_FoldMapRun[_Same[Int], _IntSum, Never](_Same[Int]()), rebind_var[Deque[Int]](self.value^)))

    def sum[dtype: DType, size: SIMDLength, //](deinit self) raises Never -> Piped[SIMD[dtype, size]] where Self.Value == Deque[SIMD[dtype, size]]:
        """Add in order from zero, preserving the numeric type and SIMD lanes."""
        comptime assert Self.Value == Deque[SIMD[dtype, size]]
        return Piped(_run_terminal(_FoldMapRun[_Same[SIMD[dtype, size]], _SIMDSum[dtype, size], Never](_Same[SIMD[dtype, size]]()), rebind_var[Deque[SIMD[dtype, size]]](self.value^)))

    def sum_by[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> Piped[Int] where Self.Value == Deque[A] and R == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Deque[A]
        return Piped(_run_terminal(_FoldMapRun[_NativeUnaryRef[A, R, Never, F, False, o], _IntSum, Never](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[Deque[A]](self.value^)))

    def sum_by[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Int] where Self.Value == Deque[A] and R == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Deque[A]
        return Piped(_run_terminal(_FoldMapRun[_NativeUnaryRef[A, R, E, F, True, o], _IntSum, E](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[Deque[A]](self.value^)))

    def sum_by[F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises F.Error -> Piped[Int] where Self.Value == Deque[F.Arg] and F.Out == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Deque[F.Arg]
        return Piped(_run_terminal(_FoldMapRun[F, _IntSum, F.Error](function^), rebind_var[Deque[F.Arg]](self.value^)))

    def sum_by[F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises F._View[o].Error -> Piped[Int] where Self.Value == Deque[F._View[o].Arg] and F._View[o].Out == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Deque[F._View[o].Arg]
        return Piped(_run_terminal(_FoldMapRun[F._View[o], _IntSum, F._View[o].Error](function._unary_view()), rebind_var[Deque[F._View[o].Arg]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> Piped[SIMD[dtype, size]] where Self.Value == Deque[A] and R == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Deque[A]
        return Piped(_run_terminal(_FoldMapRun[_NativeUnaryRef[A, R, Never, F, False, o], _SIMDSum[dtype, size], Never](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[Deque[A]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> Piped[SIMD[dtype, size]] where Self.Value == Deque[A] and R == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Deque[A]
        return Piped(_run_terminal(_FoldMapRun[_NativeUnaryRef[A, R, E, F, True, o], _SIMDSum[dtype, size], E](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[Deque[A]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises F.Error -> Piped[SIMD[dtype, size]] where Self.Value == Deque[F.Arg] and F.Out == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Deque[F.Arg]
        return Piped(_run_terminal(_FoldMapRun[F, _SIMDSum[dtype, size], F.Error](function^), rebind_var[Deque[F.Arg]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises F._View[o].Error -> Piped[SIMD[dtype, size]] where Self.Value == Deque[F._View[o].Arg] and F._View[o].Out == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Deque[F._View[o].Arg]
        return Piped(_run_terminal(_FoldMapRun[F._View[o], _SIMDSum[dtype, size], F._View[o].Error](function._unary_view()), rebind_var[Deque[F._View[o].Arg]](self.value^)))


    def find_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> Piped[R] where Self.Value == LinkedList[A]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == LinkedList[A]
        return Piped(_run_terminal(_FindMapRun[_NativeUnaryRef[A, R, Never, F, False, o]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[LinkedList[A]](self.value^)))

    def find_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> Piped[R] where Self.Value == LinkedList[A]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == LinkedList[A]
        return Piped(_run_terminal(_FindMapRun[_NativeUnaryRef[A, R, E, F, True, o]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[LinkedList[A]](self.value^)))

    def find_map[F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises F.Error -> Piped[F.Out] where Self.Value == LinkedList[F.Arg]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == LinkedList[F.Arg]
        return Piped(_run_terminal(_FindMapRun[F](function^), rebind_var[LinkedList[F.Arg]](self.value^)))

    def find_map[F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises F._View[o].Error -> Piped[F._View[o].Out] where Self.Value == LinkedList[F._View[o].Arg]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == LinkedList[F._View[o].Arg]
        return Piped(_run_terminal(_FindMapRun[F._View[o]](function._unary_view()), rebind_var[LinkedList[F._View[o].Arg]](self.value^)))

    def fold_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, M: Monoid, F: _Unary[A, R]](deinit self, ref[o] function: F) raises _CommonError[Never, M.Error] -> Piped[M.Value] where Self.Value == LinkedList[A]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == LinkedList[A]
        return Piped(_run_terminal(_FoldMapRun[_NativeUnaryRef[A, R, Never, F, False, o], M, _CommonError[Never, M.Error]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[LinkedList[A]](self.value^)))

    def fold_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, M: Monoid, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises _CommonError[E, M.Error] -> Piped[M.Value] where Self.Value == LinkedList[A]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == LinkedList[A]
        return Piped(_run_terminal(_FoldMapRun[_NativeUnaryRef[A, R, E, F, True, o], M, _CommonError[E, M.Error]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[LinkedList[A]](self.value^)))

    def fold_map[F: UnaryContract & Movable & Deinitable, //, M: Monoid](deinit self, var function: F) raises _CommonError[F.Error, M.Error] -> Piped[M.Value] where Self.Value == LinkedList[F.Arg]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == LinkedList[F.Arg]
        return Piped(_run_terminal(_FoldMapRun[F, M, _CommonError[F.Error, M.Error]](function^), rebind_var[LinkedList[F.Arg]](self.value^)))

    def fold_map[F: _UnaryViewable, o: ImmOrigin, //, M: Monoid](deinit self, ref[o] function: F) raises _CommonError[F._View[o].Error, M.Error] -> Piped[M.Value] where Self.Value == LinkedList[F._View[o].Arg]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == LinkedList[F._View[o].Arg]
        return Piped(_run_terminal(_FoldMapRun[F._View[o], M, _CommonError[F._View[o].Error, M.Error]](function._unary_view()), rebind_var[LinkedList[F._View[o].Arg]](self.value^)))

    def combine_all[M: Monoid](deinit self) raises _CommonError[Never, M.Error] -> Piped[M.Value] where Self.Value == LinkedList[M.Value]:
        """Combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == LinkedList[M.Value]
        return Piped(_run_terminal(_FoldMapRun[_Same[M.Value], M, _CommonError[Never, M.Error]](_Same[M.Value]()), rebind_var[LinkedList[M.Value]](self.value^)))

    def min_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == LinkedList[downcast[P, Movable & Deinitable]] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == LinkedList[downcast[P, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[LinkedList[downcast[P, Movable & Deinitable]]](self.value^)))

    def min_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == LinkedList[downcast[P, Movable & Deinitable]] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == LinkedList[downcast[P, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[LinkedList[downcast[P, Movable & Deinitable]]](self.value^)))

    def min_by[C: BorrowCallContract & Movable & Deinitable, //](deinit self, var function: C) raises C.Failure -> Piped[Optional[downcast[C.Payload, Movable & Deinitable]]] where Self.Value == LinkedList[downcast[C.Payload, Movable & Deinitable]] and conforms_to(C.Result, Comparable & Movable & Deinitable) and RepeatableBorrow[C]:
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == LinkedList[downcast[C.Payload, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[C.Payload, Movable & Deinitable], C, True](function^), rebind_var[LinkedList[downcast[C.Payload, Movable & Deinitable]]](self.value^)))

    def min_by[C: _BorrowViewable, o: ImmOrigin, //](deinit self, ref[o] function: C) raises C._BorrowView[o].Failure -> Piped[Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]] where Self.Value == LinkedList[downcast[C._BorrowView[o].Payload, Movable & Deinitable]] and conforms_to(C._BorrowView[o].Result, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == LinkedList[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[C._BorrowView[o].Payload, Movable & Deinitable], C._BorrowView[o], True](function._borrow_view()), rebind_var[LinkedList[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]](self.value^)))

    def max_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == LinkedList[downcast[P, Movable & Deinitable]] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == LinkedList[downcast[P, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], False](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[LinkedList[downcast[P, Movable & Deinitable]]](self.value^)))

    def max_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == LinkedList[downcast[P, Movable & Deinitable]] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == LinkedList[downcast[P, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], False](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[LinkedList[downcast[P, Movable & Deinitable]]](self.value^)))

    def max_by[C: BorrowCallContract & Movable & Deinitable, //](deinit self, var function: C) raises C.Failure -> Piped[Optional[downcast[C.Payload, Movable & Deinitable]]] where Self.Value == LinkedList[downcast[C.Payload, Movable & Deinitable]] and conforms_to(C.Result, Comparable & Movable & Deinitable) and RepeatableBorrow[C]:
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == LinkedList[downcast[C.Payload, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[C.Payload, Movable & Deinitable], C, False](function^), rebind_var[LinkedList[downcast[C.Payload, Movable & Deinitable]]](self.value^)))

    def max_by[C: _BorrowViewable, o: ImmOrigin, //](deinit self, ref[o] function: C) raises C._BorrowView[o].Failure -> Piped[Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]] where Self.Value == LinkedList[downcast[C._BorrowView[o].Payload, Movable & Deinitable]] and conforms_to(C._BorrowView[o].Result, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == LinkedList[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[C._BorrowView[o].Payload, Movable & Deinitable], C._BorrowView[o], False](function._borrow_view()), rebind_var[LinkedList[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]](self.value^)))

    def sum(deinit self) raises Never -> Piped[Int] where Self.Value == LinkedList[Int]:
        """Add in order from zero, preserving the numeric type and SIMD lanes."""
        comptime assert Self.Value == LinkedList[Int]
        return Piped(_run_terminal(_FoldMapRun[_Same[Int], _IntSum, Never](_Same[Int]()), rebind_var[LinkedList[Int]](self.value^)))

    def sum[dtype: DType, size: SIMDLength, //](deinit self) raises Never -> Piped[SIMD[dtype, size]] where Self.Value == LinkedList[SIMD[dtype, size]]:
        """Add in order from zero, preserving the numeric type and SIMD lanes."""
        comptime assert Self.Value == LinkedList[SIMD[dtype, size]]
        return Piped(_run_terminal(_FoldMapRun[_Same[SIMD[dtype, size]], _SIMDSum[dtype, size], Never](_Same[SIMD[dtype, size]]()), rebind_var[LinkedList[SIMD[dtype, size]]](self.value^)))

    def sum_by[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> Piped[Int] where Self.Value == LinkedList[A] and R == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == LinkedList[A]
        return Piped(_run_terminal(_FoldMapRun[_NativeUnaryRef[A, R, Never, F, False, o], _IntSum, Never](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[LinkedList[A]](self.value^)))

    def sum_by[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Int] where Self.Value == LinkedList[A] and R == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == LinkedList[A]
        return Piped(_run_terminal(_FoldMapRun[_NativeUnaryRef[A, R, E, F, True, o], _IntSum, E](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[LinkedList[A]](self.value^)))

    def sum_by[F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises F.Error -> Piped[Int] where Self.Value == LinkedList[F.Arg] and F.Out == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == LinkedList[F.Arg]
        return Piped(_run_terminal(_FoldMapRun[F, _IntSum, F.Error](function^), rebind_var[LinkedList[F.Arg]](self.value^)))

    def sum_by[F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises F._View[o].Error -> Piped[Int] where Self.Value == LinkedList[F._View[o].Arg] and F._View[o].Out == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == LinkedList[F._View[o].Arg]
        return Piped(_run_terminal(_FoldMapRun[F._View[o], _IntSum, F._View[o].Error](function._unary_view()), rebind_var[LinkedList[F._View[o].Arg]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> Piped[SIMD[dtype, size]] where Self.Value == LinkedList[A] and R == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == LinkedList[A]
        return Piped(_run_terminal(_FoldMapRun[_NativeUnaryRef[A, R, Never, F, False, o], _SIMDSum[dtype, size], Never](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[LinkedList[A]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> Piped[SIMD[dtype, size]] where Self.Value == LinkedList[A] and R == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == LinkedList[A]
        return Piped(_run_terminal(_FoldMapRun[_NativeUnaryRef[A, R, E, F, True, o], _SIMDSum[dtype, size], E](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[LinkedList[A]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises F.Error -> Piped[SIMD[dtype, size]] where Self.Value == LinkedList[F.Arg] and F.Out == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == LinkedList[F.Arg]
        return Piped(_run_terminal(_FoldMapRun[F, _SIMDSum[dtype, size], F.Error](function^), rebind_var[LinkedList[F.Arg]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises F._View[o].Error -> Piped[SIMD[dtype, size]] where Self.Value == LinkedList[F._View[o].Arg] and F._View[o].Out == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == LinkedList[F._View[o].Arg]
        return Piped(_run_terminal(_FoldMapRun[F._View[o], _SIMDSum[dtype, size], F._View[o].Error](function._unary_view()), rebind_var[LinkedList[F._View[o].Arg]](self.value^)))


    def find_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> Piped[R] where Self.Value == Dict[K, A, H]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == Dict[K, A, H]
        return Piped(_dict_terminal(_FindMapRun[_NativeUnaryRef[A, R, Never, F, False, o]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[Dict[K, A, H]](self.value^)))

    def find_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> Piped[R] where Self.Value == Dict[K, A, H]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == Dict[K, A, H]
        return Piped(_dict_terminal(_FindMapRun[_NativeUnaryRef[A, R, E, F, True, o]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[Dict[K, A, H]](self.value^)))

    def find_map[F: UnaryContract & Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //](deinit self, var function: F) raises F.Error -> Piped[F.Out] where Self.Value == Dict[K, F.Arg, H]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == Dict[K, F.Arg, H]
        return Piped(_dict_terminal(_FindMapRun[F](function^), rebind_var[Dict[K, F.Arg, H]](self.value^)))

    def find_map[F: _UnaryViewable, o: ImmOrigin, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //](deinit self, ref[o] function: F) raises F._View[o].Error -> Piped[F._View[o].Out] where Self.Value == Dict[K, F._View[o].Arg, H]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == Dict[K, F._View[o].Arg, H]
        return Piped(_dict_terminal(_FindMapRun[F._View[o]](function._unary_view()), rebind_var[Dict[K, F._View[o].Arg, H]](self.value^)))

    def fold_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //, M: Monoid, F: _Unary[A, R]](deinit self, ref[o] function: F) raises _CommonError[Never, M.Error] -> Piped[M.Value] where Self.Value == Dict[K, A, H]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == Dict[K, A, H]
        return Piped(_dict_terminal(_FoldMapRun[_NativeUnaryRef[A, R, Never, F, False, o], M, _CommonError[Never, M.Error]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[Dict[K, A, H]](self.value^)))

    def fold_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //, M: Monoid, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises _CommonError[E, M.Error] -> Piped[M.Value] where Self.Value == Dict[K, A, H]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == Dict[K, A, H]
        return Piped(_dict_terminal(_FoldMapRun[_NativeUnaryRef[A, R, E, F, True, o], M, _CommonError[E, M.Error]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[Dict[K, A, H]](self.value^)))

    def fold_map[F: UnaryContract & Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //, M: Monoid](deinit self, var function: F) raises _CommonError[F.Error, M.Error] -> Piped[M.Value] where Self.Value == Dict[K, F.Arg, H]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == Dict[K, F.Arg, H]
        return Piped(_dict_terminal(_FoldMapRun[F, M, _CommonError[F.Error, M.Error]](function^), rebind_var[Dict[K, F.Arg, H]](self.value^)))

    def fold_map[F: _UnaryViewable, o: ImmOrigin, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //, M: Monoid](deinit self, ref[o] function: F) raises _CommonError[F._View[o].Error, M.Error] -> Piped[M.Value] where Self.Value == Dict[K, F._View[o].Arg, H]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == Dict[K, F._View[o].Arg, H]
        return Piped(_dict_terminal(_FoldMapRun[F._View[o], M, _CommonError[F._View[o].Error, M.Error]](function._unary_view()), rebind_var[Dict[K, F._View[o].Arg, H]](self.value^)))

    def combine_all[K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //, M: Monoid](deinit self) raises _CommonError[Never, M.Error] -> Piped[M.Value] where Self.Value == Dict[K, M.Value, H]:
        """Combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == Dict[K, M.Value, H]
        return Piped(_dict_terminal(_FoldMapRun[_Same[M.Value], M, _CommonError[Never, M.Error]](_Same[M.Value]()), rebind_var[Dict[K, M.Value, H]](self.value^)))

    def min_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == Dict[K, downcast[P, Movable & Deinitable], H] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Dict[K, downcast[P, Movable & Deinitable], H]
        return Piped(_dict_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[Dict[K, downcast[P, Movable & Deinitable], H]](self.value^)))

    def min_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == Dict[K, downcast[P, Movable & Deinitable], H] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Dict[K, downcast[P, Movable & Deinitable], H]
        return Piped(_dict_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[Dict[K, downcast[P, Movable & Deinitable], H]](self.value^)))

    def min_by[C: BorrowCallContract & Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //](deinit self, var function: C) raises C.Failure -> Piped[Optional[downcast[C.Payload, Movable & Deinitable]]] where Self.Value == Dict[K, downcast[C.Payload, Movable & Deinitable], H] and conforms_to(C.Result, Comparable & Movable & Deinitable) and RepeatableBorrow[C]:
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Dict[K, downcast[C.Payload, Movable & Deinitable], H]
        return Piped(_dict_terminal(_ExtremumRun[downcast[C.Payload, Movable & Deinitable], C, True](function^), rebind_var[Dict[K, downcast[C.Payload, Movable & Deinitable], H]](self.value^)))

    def min_by[C: _BorrowViewable, o: ImmOrigin, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //](deinit self, ref[o] function: C) raises C._BorrowView[o].Failure -> Piped[Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]] where Self.Value == Dict[K, downcast[C._BorrowView[o].Payload, Movable & Deinitable], H] and conforms_to(C._BorrowView[o].Result, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Dict[K, downcast[C._BorrowView[o].Payload, Movable & Deinitable], H]
        return Piped(_dict_terminal(_ExtremumRun[downcast[C._BorrowView[o].Payload, Movable & Deinitable], C._BorrowView[o], True](function._borrow_view()), rebind_var[Dict[K, downcast[C._BorrowView[o].Payload, Movable & Deinitable], H]](self.value^)))

    def max_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == Dict[K, downcast[P, Movable & Deinitable], H] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Dict[K, downcast[P, Movable & Deinitable], H]
        return Piped(_dict_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], False](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[Dict[K, downcast[P, Movable & Deinitable], H]](self.value^)))

    def max_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == Dict[K, downcast[P, Movable & Deinitable], H] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Dict[K, downcast[P, Movable & Deinitable], H]
        return Piped(_dict_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], False](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[Dict[K, downcast[P, Movable & Deinitable], H]](self.value^)))

    def max_by[C: BorrowCallContract & Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //](deinit self, var function: C) raises C.Failure -> Piped[Optional[downcast[C.Payload, Movable & Deinitable]]] where Self.Value == Dict[K, downcast[C.Payload, Movable & Deinitable], H] and conforms_to(C.Result, Comparable & Movable & Deinitable) and RepeatableBorrow[C]:
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Dict[K, downcast[C.Payload, Movable & Deinitable], H]
        return Piped(_dict_terminal(_ExtremumRun[downcast[C.Payload, Movable & Deinitable], C, False](function^), rebind_var[Dict[K, downcast[C.Payload, Movable & Deinitable], H]](self.value^)))

    def max_by[C: _BorrowViewable, o: ImmOrigin, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //](deinit self, ref[o] function: C) raises C._BorrowView[o].Failure -> Piped[Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]] where Self.Value == Dict[K, downcast[C._BorrowView[o].Payload, Movable & Deinitable], H] and conforms_to(C._BorrowView[o].Result, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Dict[K, downcast[C._BorrowView[o].Payload, Movable & Deinitable], H]
        return Piped(_dict_terminal(_ExtremumRun[downcast[C._BorrowView[o].Payload, Movable & Deinitable], C._BorrowView[o], False](function._borrow_view()), rebind_var[Dict[K, downcast[C._BorrowView[o].Payload, Movable & Deinitable], H]](self.value^)))

    def sum[K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //](deinit self) raises Never -> Piped[Int] where Self.Value == Dict[K, Int, H]:
        """Add in order from zero, preserving the numeric type and SIMD lanes."""
        comptime assert Self.Value == Dict[K, Int, H]
        return Piped(_dict_terminal(_FoldMapRun[_Same[Int], _IntSum, Never](_Same[Int]()), rebind_var[Dict[K, Int, H]](self.value^)))

    def sum[dtype: DType, size: SIMDLength, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //](deinit self) raises Never -> Piped[SIMD[dtype, size]] where Self.Value == Dict[K, SIMD[dtype, size], H]:
        """Add in order from zero, preserving the numeric type and SIMD lanes."""
        comptime assert Self.Value == Dict[K, SIMD[dtype, size], H]
        return Piped(_dict_terminal(_FoldMapRun[_Same[SIMD[dtype, size]], _SIMDSum[dtype, size], Never](_Same[SIMD[dtype, size]]()), rebind_var[Dict[K, SIMD[dtype, size], H]](self.value^)))

    def sum_by[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> Piped[Int] where Self.Value == Dict[K, A, H] and R == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Dict[K, A, H]
        return Piped(_dict_terminal(_FoldMapRun[_NativeUnaryRef[A, R, Never, F, False, o], _IntSum, Never](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[Dict[K, A, H]](self.value^)))

    def sum_by[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Int] where Self.Value == Dict[K, A, H] and R == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Dict[K, A, H]
        return Piped(_dict_terminal(_FoldMapRun[_NativeUnaryRef[A, R, E, F, True, o], _IntSum, E](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[Dict[K, A, H]](self.value^)))

    def sum_by[F: UnaryContract & Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //](deinit self, var function: F) raises F.Error -> Piped[Int] where Self.Value == Dict[K, F.Arg, H] and F.Out == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Dict[K, F.Arg, H]
        return Piped(_dict_terminal(_FoldMapRun[F, _IntSum, F.Error](function^), rebind_var[Dict[K, F.Arg, H]](self.value^)))

    def sum_by[F: _UnaryViewable, o: ImmOrigin, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //](deinit self, ref[o] function: F) raises F._View[o].Error -> Piped[Int] where Self.Value == Dict[K, F._View[o].Arg, H] and F._View[o].Out == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Dict[K, F._View[o].Arg, H]
        return Piped(_dict_terminal(_FoldMapRun[F._View[o], _IntSum, F._View[o].Error](function._unary_view()), rebind_var[Dict[K, F._View[o].Arg, H]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> Piped[SIMD[dtype, size]] where Self.Value == Dict[K, A, H] and R == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Dict[K, A, H]
        return Piped(_dict_terminal(_FoldMapRun[_NativeUnaryRef[A, R, Never, F, False, o], _SIMDSum[dtype, size], Never](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[Dict[K, A, H]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> Piped[SIMD[dtype, size]] where Self.Value == Dict[K, A, H] and R == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Dict[K, A, H]
        return Piped(_dict_terminal(_FoldMapRun[_NativeUnaryRef[A, R, E, F, True, o], _SIMDSum[dtype, size], E](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[Dict[K, A, H]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, F: UnaryContract & Movable & Deinitable, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //](deinit self, var function: F) raises F.Error -> Piped[SIMD[dtype, size]] where Self.Value == Dict[K, F.Arg, H] and F.Out == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Dict[K, F.Arg, H]
        return Piped(_dict_terminal(_FoldMapRun[F, _SIMDSum[dtype, size], F.Error](function^), rebind_var[Dict[K, F.Arg, H]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, F: _UnaryViewable, o: ImmOrigin, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, //](deinit self, ref[o] function: F) raises F._View[o].Error -> Piped[SIMD[dtype, size]] where Self.Value == Dict[K, F._View[o].Arg, H] and F._View[o].Out == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Dict[K, F._View[o].Arg, H]
        return Piped(_dict_terminal(_FoldMapRun[F._View[o], _SIMDSum[dtype, size], F._View[o].Error](function._unary_view()), rebind_var[Dict[K, F._View[o].Arg, H]](self.value^)))


    def find_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> Piped[R] where Self.Value == StringDict[A]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == StringDict[A]
        return Piped(_string_dict_terminal(_FindMapRun[_NativeUnaryRef[A, R, Never, F, False, o]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[StringDict[A]](self.value^)))

    def find_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> Piped[R] where Self.Value == StringDict[A]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == StringDict[A]
        return Piped(_string_dict_terminal(_FindMapRun[_NativeUnaryRef[A, R, E, F, True, o]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[StringDict[A]](self.value^)))

    def find_map[F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises F.Error -> Piped[F.Out] where Self.Value == StringDict[F.Arg]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == StringDict[F.Arg]
        return Piped(_string_dict_terminal(_FindMapRun[F](function^), rebind_var[StringDict[F.Arg]](self.value^)))

    def find_map[F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises F._View[o].Error -> Piped[F._View[o].Out] where Self.Value == StringDict[F._View[o].Arg]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == StringDict[F._View[o].Arg]
        return Piped(_string_dict_terminal(_FindMapRun[F._View[o]](function._unary_view()), rebind_var[StringDict[F._View[o].Arg]](self.value^)))

    def fold_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, M: Monoid, F: _Unary[A, R]](deinit self, ref[o] function: F) raises _CommonError[Never, M.Error] -> Piped[M.Value] where Self.Value == StringDict[A]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == StringDict[A]
        return Piped(_string_dict_terminal(_FoldMapRun[_NativeUnaryRef[A, R, Never, F, False, o], M, _CommonError[Never, M.Error]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[StringDict[A]](self.value^)))

    def fold_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, M: Monoid, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises _CommonError[E, M.Error] -> Piped[M.Value] where Self.Value == StringDict[A]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == StringDict[A]
        return Piped(_string_dict_terminal(_FoldMapRun[_NativeUnaryRef[A, R, E, F, True, o], M, _CommonError[E, M.Error]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[StringDict[A]](self.value^)))

    def fold_map[F: UnaryContract & Movable & Deinitable, //, M: Monoid](deinit self, var function: F) raises _CommonError[F.Error, M.Error] -> Piped[M.Value] where Self.Value == StringDict[F.Arg]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == StringDict[F.Arg]
        return Piped(_string_dict_terminal(_FoldMapRun[F, M, _CommonError[F.Error, M.Error]](function^), rebind_var[StringDict[F.Arg]](self.value^)))

    def fold_map[F: _UnaryViewable, o: ImmOrigin, //, M: Monoid](deinit self, ref[o] function: F) raises _CommonError[F._View[o].Error, M.Error] -> Piped[M.Value] where Self.Value == StringDict[F._View[o].Arg]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == StringDict[F._View[o].Arg]
        return Piped(_string_dict_terminal(_FoldMapRun[F._View[o], M, _CommonError[F._View[o].Error, M.Error]](function._unary_view()), rebind_var[StringDict[F._View[o].Arg]](self.value^)))

    def combine_all[M: Monoid](deinit self) raises _CommonError[Never, M.Error] -> Piped[M.Value] where Self.Value == StringDict[M.Value]:
        """Combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == StringDict[M.Value]
        return Piped(_string_dict_terminal(_FoldMapRun[_Same[M.Value], M, _CommonError[Never, M.Error]](_Same[M.Value]()), rebind_var[StringDict[M.Value]](self.value^)))

    def min_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == StringDict[downcast[P, Movable & Deinitable]] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == StringDict[downcast[P, Movable & Deinitable]]
        return Piped(_string_dict_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[StringDict[downcast[P, Movable & Deinitable]]](self.value^)))

    def min_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == StringDict[downcast[P, Movable & Deinitable]] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == StringDict[downcast[P, Movable & Deinitable]]
        return Piped(_string_dict_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[StringDict[downcast[P, Movable & Deinitable]]](self.value^)))

    def min_by[C: BorrowCallContract & Movable & Deinitable, //](deinit self, var function: C) raises C.Failure -> Piped[Optional[downcast[C.Payload, Movable & Deinitable]]] where Self.Value == StringDict[downcast[C.Payload, Movable & Deinitable]] and conforms_to(C.Result, Comparable & Movable & Deinitable) and RepeatableBorrow[C]:
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == StringDict[downcast[C.Payload, Movable & Deinitable]]
        return Piped(_string_dict_terminal(_ExtremumRun[downcast[C.Payload, Movable & Deinitable], C, True](function^), rebind_var[StringDict[downcast[C.Payload, Movable & Deinitable]]](self.value^)))

    def min_by[C: _BorrowViewable, o: ImmOrigin, //](deinit self, ref[o] function: C) raises C._BorrowView[o].Failure -> Piped[Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]] where Self.Value == StringDict[downcast[C._BorrowView[o].Payload, Movable & Deinitable]] and conforms_to(C._BorrowView[o].Result, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == StringDict[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]
        return Piped(_string_dict_terminal(_ExtremumRun[downcast[C._BorrowView[o].Payload, Movable & Deinitable], C._BorrowView[o], True](function._borrow_view()), rebind_var[StringDict[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]](self.value^)))

    def max_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == StringDict[downcast[P, Movable & Deinitable]] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == StringDict[downcast[P, Movable & Deinitable]]
        return Piped(_string_dict_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], False](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[StringDict[downcast[P, Movable & Deinitable]]](self.value^)))

    def max_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == StringDict[downcast[P, Movable & Deinitable]] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == StringDict[downcast[P, Movable & Deinitable]]
        return Piped(_string_dict_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], False](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[StringDict[downcast[P, Movable & Deinitable]]](self.value^)))

    def max_by[C: BorrowCallContract & Movable & Deinitable, //](deinit self, var function: C) raises C.Failure -> Piped[Optional[downcast[C.Payload, Movable & Deinitable]]] where Self.Value == StringDict[downcast[C.Payload, Movable & Deinitable]] and conforms_to(C.Result, Comparable & Movable & Deinitable) and RepeatableBorrow[C]:
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == StringDict[downcast[C.Payload, Movable & Deinitable]]
        return Piped(_string_dict_terminal(_ExtremumRun[downcast[C.Payload, Movable & Deinitable], C, False](function^), rebind_var[StringDict[downcast[C.Payload, Movable & Deinitable]]](self.value^)))

    def max_by[C: _BorrowViewable, o: ImmOrigin, //](deinit self, ref[o] function: C) raises C._BorrowView[o].Failure -> Piped[Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]] where Self.Value == StringDict[downcast[C._BorrowView[o].Payload, Movable & Deinitable]] and conforms_to(C._BorrowView[o].Result, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == StringDict[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]
        return Piped(_string_dict_terminal(_ExtremumRun[downcast[C._BorrowView[o].Payload, Movable & Deinitable], C._BorrowView[o], False](function._borrow_view()), rebind_var[StringDict[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]](self.value^)))

    def sum(deinit self) raises Never -> Piped[Int] where Self.Value == StringDict[Int]:
        """Add in order from zero, preserving the numeric type and SIMD lanes."""
        comptime assert Self.Value == StringDict[Int]
        return Piped(_string_dict_terminal(_FoldMapRun[_Same[Int], _IntSum, Never](_Same[Int]()), rebind_var[StringDict[Int]](self.value^)))

    def sum[dtype: DType, size: SIMDLength, //](deinit self) raises Never -> Piped[SIMD[dtype, size]] where Self.Value == StringDict[SIMD[dtype, size]]:
        """Add in order from zero, preserving the numeric type and SIMD lanes."""
        comptime assert Self.Value == StringDict[SIMD[dtype, size]]
        return Piped(_string_dict_terminal(_FoldMapRun[_Same[SIMD[dtype, size]], _SIMDSum[dtype, size], Never](_Same[SIMD[dtype, size]]()), rebind_var[StringDict[SIMD[dtype, size]]](self.value^)))

    def sum_by[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> Piped[Int] where Self.Value == StringDict[A] and R == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == StringDict[A]
        return Piped(_string_dict_terminal(_FoldMapRun[_NativeUnaryRef[A, R, Never, F, False, o], _IntSum, Never](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[StringDict[A]](self.value^)))

    def sum_by[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Int] where Self.Value == StringDict[A] and R == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == StringDict[A]
        return Piped(_string_dict_terminal(_FoldMapRun[_NativeUnaryRef[A, R, E, F, True, o], _IntSum, E](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[StringDict[A]](self.value^)))

    def sum_by[F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises F.Error -> Piped[Int] where Self.Value == StringDict[F.Arg] and F.Out == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == StringDict[F.Arg]
        return Piped(_string_dict_terminal(_FoldMapRun[F, _IntSum, F.Error](function^), rebind_var[StringDict[F.Arg]](self.value^)))

    def sum_by[F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises F._View[o].Error -> Piped[Int] where Self.Value == StringDict[F._View[o].Arg] and F._View[o].Out == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == StringDict[F._View[o].Arg]
        return Piped(_string_dict_terminal(_FoldMapRun[F._View[o], _IntSum, F._View[o].Error](function._unary_view()), rebind_var[StringDict[F._View[o].Arg]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> Piped[SIMD[dtype, size]] where Self.Value == StringDict[A] and R == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == StringDict[A]
        return Piped(_string_dict_terminal(_FoldMapRun[_NativeUnaryRef[A, R, Never, F, False, o], _SIMDSum[dtype, size], Never](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[StringDict[A]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> Piped[SIMD[dtype, size]] where Self.Value == StringDict[A] and R == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == StringDict[A]
        return Piped(_string_dict_terminal(_FoldMapRun[_NativeUnaryRef[A, R, E, F, True, o], _SIMDSum[dtype, size], E](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[StringDict[A]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises F.Error -> Piped[SIMD[dtype, size]] where Self.Value == StringDict[F.Arg] and F.Out == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == StringDict[F.Arg]
        return Piped(_string_dict_terminal(_FoldMapRun[F, _SIMDSum[dtype, size], F.Error](function^), rebind_var[StringDict[F.Arg]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises F._View[o].Error -> Piped[SIMD[dtype, size]] where Self.Value == StringDict[F._View[o].Arg] and F._View[o].Out == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == StringDict[F._View[o].Arg]
        return Piped(_string_dict_terminal(_FoldMapRun[F._View[o], _SIMDSum[dtype, size], F._View[o].Error](function._unary_view()), rebind_var[StringDict[F._View[o].Arg]](self.value^)))


    def find_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> Piped[R] where Self.Value == Optional[A]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == Optional[A]
        return Piped(_run_terminal(_FindMapRun[_NativeUnaryRef[A, R, Never, F, False, o]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[Optional[A]](self.value^)))

    def find_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> Piped[R] where Self.Value == Optional[A]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == Optional[A]
        return Piped(_run_terminal(_FindMapRun[_NativeUnaryRef[A, R, E, F, True, o]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[Optional[A]](self.value^)))

    def find_map[F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises F.Error -> Piped[F.Out] where Self.Value == Optional[F.Arg]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == Optional[F.Arg]
        return Piped(_run_terminal(_FindMapRun[F](function^), rebind_var[Optional[F.Arg]](self.value^)))

    def find_map[F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises F._View[o].Error -> Piped[F._View[o].Out] where Self.Value == Optional[F._View[o].Arg]:
        """Return the first present transformed result, stopping without another pull."""
        comptime assert Self.Value == Optional[F._View[o].Arg]
        return Piped(_run_terminal(_FindMapRun[F._View[o]](function._unary_view()), rebind_var[Optional[F._View[o].Arg]](self.value^)))

    def fold_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, M: Monoid, F: _Unary[A, R]](deinit self, ref[o] function: F) raises _CommonError[Never, M.Error] -> Piped[M.Value] where Self.Value == Optional[A]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == Optional[A]
        return Piped(_run_terminal(_FoldMapRun[_NativeUnaryRef[A, R, Never, F, False, o], M, _CommonError[Never, M.Error]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[Optional[A]](self.value^)))

    def fold_map[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, M: Monoid, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises _CommonError[E, M.Error] -> Piped[M.Value] where Self.Value == Optional[A]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == Optional[A]
        return Piped(_run_terminal(_FoldMapRun[_NativeUnaryRef[A, R, E, F, True, o], M, _CommonError[E, M.Error]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[Optional[A]](self.value^)))

    def fold_map[F: UnaryContract & Movable & Deinitable, //, M: Monoid](deinit self, var function: F) raises _CommonError[F.Error, M.Error] -> Piped[M.Value] where Self.Value == Optional[F.Arg]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == Optional[F.Arg]
        return Piped(_run_terminal(_FoldMapRun[F, M, _CommonError[F.Error, M.Error]](function^), rebind_var[Optional[F.Arg]](self.value^)))

    def fold_map[F: _UnaryViewable, o: ImmOrigin, //, M: Monoid](deinit self, ref[o] function: F) raises _CommonError[F._View[o].Error, M.Error] -> Piped[M.Value] where Self.Value == Optional[F._View[o].Arg]:
        """Project and combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == Optional[F._View[o].Arg]
        return Piped(_run_terminal(_FoldMapRun[F._View[o], M, _CommonError[F._View[o].Error, M.Error]](function._unary_view()), rebind_var[Optional[F._View[o].Arg]](self.value^)))

    def combine_all[M: Monoid](deinit self) raises _CommonError[Never, M.Error] -> Piped[M.Value] where Self.Value == Optional[M.Value]:
        """Combine in order with a monoid; empty input returns its identity."""
        comptime assert Self.Value == Optional[M.Value]
        return Piped(_run_terminal(_FoldMapRun[_Same[M.Value], M, _CommonError[Never, M.Error]](_Same[M.Value]()), rebind_var[Optional[M.Value]](self.value^)))

    def min_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == Optional[downcast[P, Movable & Deinitable]] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Optional[downcast[P, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[Optional[downcast[P, Movable & Deinitable]]](self.value^)))

    def min_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == Optional[downcast[P, Movable & Deinitable]] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Optional[downcast[P, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[Optional[downcast[P, Movable & Deinitable]]](self.value^)))

    def min_by[C: BorrowCallContract & Movable & Deinitable, //](deinit self, var function: C) raises C.Failure -> Piped[Optional[downcast[C.Payload, Movable & Deinitable]]] where Self.Value == Optional[downcast[C.Payload, Movable & Deinitable]] and conforms_to(C.Result, Comparable & Movable & Deinitable) and RepeatableBorrow[C]:
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Optional[downcast[C.Payload, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[C.Payload, Movable & Deinitable], C, True](function^), rebind_var[Optional[downcast[C.Payload, Movable & Deinitable]]](self.value^)))

    def min_by[C: _BorrowViewable, o: ImmOrigin, //](deinit self, ref[o] function: C) raises C._BorrowView[o].Failure -> Piped[Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]] where Self.Value == Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]] and conforms_to(C._BorrowView[o].Result, Comparable & Movable & Deinitable):
        """Return the element with the smallest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[C._BorrowView[o].Payload, Movable & Deinitable], C._BorrowView[o], True](function._borrow_view()), rebind_var[Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]](self.value^)))

    def max_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, F: _Borrowing[P, R]](deinit self, ref[o] function: F) raises Never -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == Optional[downcast[P, Movable & Deinitable]] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Optional[downcast[P, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, Never, F, False, o], False](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[Optional[downcast[P, Movable & Deinitable]]](self.value^)))

    def max_by[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Optional[downcast[P, Movable & Deinitable]]] where Self.Value == Optional[downcast[P, Movable & Deinitable]] and conforms_to(R, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Optional[downcast[P, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[P, Movable & Deinitable], _NativeBorrowRef[P, R, E, F, True, o], False](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[Optional[downcast[P, Movable & Deinitable]]](self.value^)))

    def max_by[C: BorrowCallContract & Movable & Deinitable, //](deinit self, var function: C) raises C.Failure -> Piped[Optional[downcast[C.Payload, Movable & Deinitable]]] where Self.Value == Optional[downcast[C.Payload, Movable & Deinitable]] and conforms_to(C.Result, Comparable & Movable & Deinitable) and RepeatableBorrow[C]:
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Optional[downcast[C.Payload, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[C.Payload, Movable & Deinitable], C, False](function^), rebind_var[Optional[downcast[C.Payload, Movable & Deinitable]]](self.value^)))

    def max_by[C: _BorrowViewable, o: ImmOrigin, //](deinit self, ref[o] function: C) raises C._BorrowView[o].Failure -> Piped[Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]] where Self.Value == Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]] and conforms_to(C._BorrowView[o].Result, Comparable & Movable & Deinitable):
        """Return the element with the largest key; empty input is absent and ties keep the first."""
        comptime assert Self.Value == Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]
        return Piped(_run_terminal(_ExtremumRun[downcast[C._BorrowView[o].Payload, Movable & Deinitable], C._BorrowView[o], False](function._borrow_view()), rebind_var[Optional[downcast[C._BorrowView[o].Payload, Movable & Deinitable]]](self.value^)))

    def sum(deinit self) raises Never -> Piped[Int] where Self.Value == Optional[Int]:
        """Add in order from zero, preserving the numeric type and SIMD lanes."""
        comptime assert Self.Value == Optional[Int]
        return Piped(_run_terminal(_FoldMapRun[_Same[Int], _IntSum, Never](_Same[Int]()), rebind_var[Optional[Int]](self.value^)))

    def sum[dtype: DType, size: SIMDLength, //](deinit self) raises Never -> Piped[SIMD[dtype, size]] where Self.Value == Optional[SIMD[dtype, size]]:
        """Add in order from zero, preserving the numeric type and SIMD lanes."""
        comptime assert Self.Value == Optional[SIMD[dtype, size]]
        return Piped(_run_terminal(_FoldMapRun[_Same[SIMD[dtype, size]], _SIMDSum[dtype, size], Never](_Same[SIMD[dtype, size]]()), rebind_var[Optional[SIMD[dtype, size]]](self.value^)))

    def sum_by[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> Piped[Int] where Self.Value == Optional[A] and R == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Optional[A]
        return Piped(_run_terminal(_FoldMapRun[_NativeUnaryRef[A, R, Never, F, False, o], _IntSum, Never](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[Optional[A]](self.value^)))

    def sum_by[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> Piped[Int] where Self.Value == Optional[A] and R == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Optional[A]
        return Piped(_run_terminal(_FoldMapRun[_NativeUnaryRef[A, R, E, F, True, o], _IntSum, E](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[Optional[A]](self.value^)))

    def sum_by[F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises F.Error -> Piped[Int] where Self.Value == Optional[F.Arg] and F.Out == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Optional[F.Arg]
        return Piped(_run_terminal(_FoldMapRun[F, _IntSum, F.Error](function^), rebind_var[Optional[F.Arg]](self.value^)))

    def sum_by[F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises F._View[o].Error -> Piped[Int] where Self.Value == Optional[F._View[o].Arg] and F._View[o].Out == Int:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Optional[F._View[o].Arg]
        return Piped(_run_terminal(_FoldMapRun[F._View[o], _IntSum, F._View[o].Error](function._unary_view()), rebind_var[Optional[F._View[o].Arg]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, F: _Unary[A, R]](deinit self, ref[o] function: F) raises Never -> Piped[SIMD[dtype, size]] where Self.Value == Optional[A] and R == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Optional[A]
        return Piped(_run_terminal(_FoldMapRun[_NativeUnaryRef[A, R, Never, F, False, o], _SIMDSum[dtype, size], Never](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))), rebind_var[Optional[A]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](deinit self, ref[o] function: F) raises E -> Piped[SIMD[dtype, size]] where Self.Value == Optional[A] and R == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Optional[A]
        return Piped(_run_terminal(_FoldMapRun[_NativeUnaryRef[A, R, E, F, True, o], _SIMDSum[dtype, size], E](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))), rebind_var[Optional[A]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, F: UnaryContract & Movable & Deinitable, //](deinit self, var function: F) raises F.Error -> Piped[SIMD[dtype, size]] where Self.Value == Optional[F.Arg] and F.Out == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Optional[F.Arg]
        return Piped(_run_terminal(_FoldMapRun[F, _SIMDSum[dtype, size], F.Error](function^), rebind_var[Optional[F.Arg]](self.value^)))

    def sum_by[dtype: DType, size: SIMDLength, F: _UnaryViewable, o: ImmOrigin, //](deinit self, ref[o] function: F) raises F._View[o].Error -> Piped[SIMD[dtype, size]] where Self.Value == Optional[F._View[o].Arg] and F._View[o].Out == SIMD[dtype, size]:
        """Project and add in one pass from zero, without an intermediate collection."""
        comptime assert Self.Value == Optional[F._View[o].Arg]
        return Piped(_run_terminal(_FoldMapRun[F._View[o], _SIMDSum[dtype, size], F._View[o].Error](function._unary_view()), rebind_var[Optional[F._View[o].Arg]](self.value^)))


    def traverse_tap[C: BorrowCallContract & Movable & Deinitable, //, S: Traversable, G: Applicative, X: AnyType = _InferError](deinit self, var function: C) raises _EntryError[X, S.TraverseError[G, Self.Value, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]]] -> Piped[S.Traversed[G, Self.Value, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]]] where S.Element[Self.Value] == downcast[C.Payload, Movable & Deinitable] and ((S.Mapped[Self.Value, _Same[S.Element[Self.Value]]] == Self.Value) if conforms_to(Self.Value, _ResultType) else True) and _CarrierCompatible[G, C.Result] and S.TargetCompatible[G, Self.Value, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]]:
        """Traverse effects and retain the original payloads on success.

        Parameters:
            C: The borrowing library callback type.
            S: The Traversable source family, preserving its native shape and origins.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect containing the original payloads; Piped preserves source shape and Iter/direct calls gather a List.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_as[S, G, Self.Value, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C], _EntryError[X, S.TraverseError[G, Self.Value, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]]]](_TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C](function^), self.value^))

    def traverse_tap[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, S: Traversable, G: Applicative, F: _Borrowing[P, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, S.TraverseError[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]]] -> Piped[S.Traversed[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]]] where S.Element[Self.Value] == downcast[P, Movable & Deinitable] and ((S.Mapped[Self.Value, _Same[S.Element[Self.Value]]] == Self.Value) if conforms_to(Self.Value, _ResultType) else True) and _CarrierCompatible[G, R] and S.TargetCompatible[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]]:
        """Traverse effects and retain the original payloads on success."""
        return Piped(_traverse_as[S, G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]], _EntryError[X, S.TraverseError[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), self.value^))

    def traverse_tap[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, S: Traversable, G: Applicative, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, S.TraverseError[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]]] -> Piped[S.Traversed[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]]] where S.Element[Self.Value] == downcast[P, Movable & Deinitable] and ((S.Mapped[Self.Value, _Same[S.Element[Self.Value]]] == Self.Value) if conforms_to(Self.Value, _ResultType) else True) and _CarrierCompatible[G, R] and S.TargetCompatible[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]]:
        """Traverse effects and retain the original payloads on success."""
        return Piped(_traverse_as[S, G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]], _EntryError[X, S.TraverseError[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), self.value^))

    def flat_traverse[F: UnaryContract & Movable & Deinitable, //, S: Traversable & Monad, G: Applicative, X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, _CommonError[S.TraverseError[G, Self.Value, F], G.MapError[S.Traversed[G, Self.Value, F], _FlattenAfter[S, G.Element[S.Traversed[G, Self.Value, F]]]]]] -> Piped[G.Mapped[S.Traversed[G, Self.Value, F], _FlattenAfter[S, G.Element[S.Traversed[G, Self.Value, F]]]]] where S.Element[Self.Value] == F.Arg and ((S.Mapped[Self.Value, _Same[S.Element[Self.Value]]] == Self.Value) if conforms_to(Self.Value, _ResultType) else True) and _ErrorCompatible[_EntryError[X, _CommonError[S.TraverseError[G, Self.Value, F], G.MapError[S.Traversed[G, Self.Value, F], _FlattenAfter[S, G.Element[S.Traversed[G, Self.Value, F]]]]]], F.Error] and ((G.Element[F.Out] == Result[downcast[G.Element[F.Out], _ResultType].Value, downcast[Self.Value, _ResultType].Error]) if conforms_to(Self.Value, _ResultType) else True) and _CarrierCompatible[G, F.Out] and S.TargetCompatible[G, Self.Value, F]:
        """Traverse effects and flatten one source-family layer inside the effect.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            S: The Traversable source family, preserving its native shape and origins.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect containing the flattened source shape. The callback produces a target effect of the same source family.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_then[S, G, Self.Value, F, _FlattenAfter[S, G.Element[S.Traversed[G, Self.Value, F]]], _EntryError[X, _CommonError[S.TraverseError[G, Self.Value, F], G.MapError[S.Traversed[G, Self.Value, F], _FlattenAfter[S, G.Element[S.Traversed[G, Self.Value, F]]]]]]](function^, self.value^, _FlattenAfter[S, G.Element[S.Traversed[G, Self.Value, F]]]()))

    def flat_traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, S: Traversable & Monad, G: Applicative, F: _Unary[A, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[S, G.Element[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]]]]]]] -> Piped[G.Mapped[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[S, G.Element[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]]]]]] where S.Element[Self.Value] == A and ((S.Mapped[Self.Value, _Same[S.Element[Self.Value]]] == Self.Value) if conforms_to(Self.Value, _ResultType) else True) and _ErrorCompatible[_EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[S, G.Element[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]]]]]]], Never] and ((G.Element[R] == Result[downcast[G.Element[R], _ResultType].Value, downcast[Self.Value, _ResultType].Error]) if conforms_to(Self.Value, _ResultType) else True) and _CarrierCompatible[G, R] and S.TargetCompatible[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]]:
        """Traverse effects and flatten one source-family layer inside the effect."""
        return Piped(_traverse_then[S, G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o], _FlattenAfter[S, G.Element[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]]]], _EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[S, G.Element[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]]]]]]]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), self.value^, _FlattenAfter[S, G.Element[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]]]]()))

    def flat_traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, S: Traversable & Monad, G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[S, G.Element[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]]]]]]] -> Piped[G.Mapped[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[S, G.Element[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]]]]]] where S.Element[Self.Value] == A and ((S.Mapped[Self.Value, _Same[S.Element[Self.Value]]] == Self.Value) if conforms_to(Self.Value, _ResultType) else True) and _ErrorCompatible[_EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[S, G.Element[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]]]]]]], E] and ((G.Element[R] == Result[downcast[G.Element[R], _ResultType].Value, downcast[Self.Value, _ResultType].Error]) if conforms_to(Self.Value, _ResultType) else True) and _CarrierCompatible[G, R] and S.TargetCompatible[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]]:
        """Traverse effects and flatten one source-family layer inside the effect."""
        return Piped(_traverse_then[S, G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o], _FlattenAfter[S, G.Element[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]]]], _EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[S, G.Element[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]]]]]]]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self.value^, _FlattenAfter[S, G.Element[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]]]]()))

    def flat_sequence[S: Traversable & Monad, G: Applicative, X: AnyType = _InferError](deinit self) raises _EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _Same[S.Element[Self.Value]]], G.MapError[S.Traversed[G, Self.Value, _Same[S.Element[Self.Value]]], _FlattenAfter[S, G.Element[S.Traversed[G, Self.Value, _Same[S.Element[Self.Value]]]]]]]] -> Piped[G.Mapped[S.Traversed[G, Self.Value, _Same[S.Element[Self.Value]]], _FlattenAfter[S, G.Element[S.Traversed[G, Self.Value, _Same[S.Element[Self.Value]]]]]]] where S.Element[Self.Value] == S.Element[Self.Value] and ((S.Mapped[Self.Value, _Same[S.Element[Self.Value]]] == Self.Value) if conforms_to(Self.Value, _ResultType) else True) and _ErrorCompatible[_EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _Same[S.Element[Self.Value]]], G.MapError[S.Traversed[G, Self.Value, _Same[S.Element[Self.Value]]], _FlattenAfter[S, G.Element[S.Traversed[G, Self.Value, _Same[S.Element[Self.Value]]]]]]]], Never] and ((G.Element[_Same[S.Element[Self.Value]].Out] == Result[downcast[G.Element[_Same[S.Element[Self.Value]].Out], _ResultType].Value, downcast[Self.Value, _ResultType].Error]) if conforms_to(Self.Value, _ResultType) else True) and _CarrierCompatible[G, _Same[S.Element[Self.Value]].Out] and S.TargetCompatible[G, Self.Value, _Same[S.Element[Self.Value]]]:
        """Traverse effects and flatten one source-family layer inside the effect.

        Parameters:
            S: The Traversable source family, preserving its native shape and origins.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Returns:
            The target effect containing the source shape after sequencing effects and flattening one source-family layer.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_then[S, G, Self.Value, _Same[S.Element[Self.Value]], _FlattenAfter[S, G.Element[S.Traversed[G, Self.Value, _Same[S.Element[Self.Value]]]]], _EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _Same[S.Element[Self.Value]]], G.MapError[S.Traversed[G, Self.Value, _Same[S.Element[Self.Value]]], _FlattenAfter[S, G.Element[S.Traversed[G, Self.Value, _Same[S.Element[Self.Value]]]]]]]]](_Same[S.Element[Self.Value]](), self.value^, _FlattenAfter[S, G.Element[S.Traversed[G, Self.Value, _Same[S.Element[Self.Value]]]]]()))

    def traverse_filter[F: UnaryContract & Movable & Deinitable, //, S: Traversable & FunctorFilter, G: Applicative, X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, _CommonError[S.TraverseError[G, Self.Value, F], G.MapError[S.Traversed[G, Self.Value, F], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, F]]]]]] -> Piped[G.Mapped[S.Traversed[G, Self.Value, F], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, F]]]]] where S.Element[Self.Value] == F.Arg and ((S.Mapped[Self.Value, _Same[S.Element[Self.Value]]] == Self.Value) if conforms_to(Self.Value, _ResultType) else True) and _ErrorCompatible[_EntryError[X, _CommonError[S.TraverseError[G, Self.Value, F], G.MapError[S.Traversed[G, Self.Value, F], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, F]]]]]], F.Error] and G.Element[F.Out] == Optional[_ListElement[G.Element[F.Out]]] and _CarrierCompatible[G, F.Out] and S.TargetCompatible[G, Self.Value, F]:
        """Traverse effects and retain present Optional payloads inside the effect.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            S: The Traversable source family, preserving its native shape and origins.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect containing present Optional results in source shape; absence discards an element and target failure follows the effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_then[S, G, Self.Value, F, _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, F]]], _EntryError[X, _CommonError[S.TraverseError[G, Self.Value, F], G.MapError[S.Traversed[G, Self.Value, F], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, F]]]]]]](function^, self.value^, _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, F]]]()))

    def traverse_filter[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, S: Traversable & FunctorFilter, G: Applicative, F: _Unary[A, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]]]]]]] -> Piped[G.Mapped[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]]]]]] where S.Element[Self.Value] == A and ((S.Mapped[Self.Value, _Same[S.Element[Self.Value]]] == Self.Value) if conforms_to(Self.Value, _ResultType) else True) and _ErrorCompatible[_EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]]]]]]], Never] and G.Element[R] == Optional[_ListElement[G.Element[R]]] and _CarrierCompatible[G, R] and S.TargetCompatible[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]]:
        """Traverse effects and retain present Optional payloads inside the effect."""
        return Piped(_traverse_then[S, G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]]]], _EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]]]]]]]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), self.value^, _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, Never, F, False, o]]]]()))

    def traverse_filter[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, S: Traversable & FunctorFilter, G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]]]]]]] -> Piped[G.Mapped[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]]]]]] where S.Element[Self.Value] == A and ((S.Mapped[Self.Value, _Same[S.Element[Self.Value]]] == Self.Value) if conforms_to(Self.Value, _ResultType) else True) and _ErrorCompatible[_EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]]]]]]], E] and G.Element[R] == Optional[_ListElement[G.Element[R]]] and _CarrierCompatible[G, R] and S.TargetCompatible[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]]:
        """Traverse effects and retain present Optional payloads inside the effect."""
        return Piped(_traverse_then[S, G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]]]], _EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]]]]]]]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), self.value^, _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _NativeUnaryRef[A, R, E, F, True, o]]]]()))

    def filter_effect[C: BorrowCallContract & Movable & Deinitable, //, S: Traversable & FunctorFilter, G: Applicative, X: AnyType = _InferError](deinit self, var function: C) raises _EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], G.MapError[S.Traversed[G, Self.Value, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]]]] -> Piped[G.Mapped[S.Traversed[G, Self.Value, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]]] where S.Element[Self.Value] == downcast[C.Payload, Movable & Deinitable] and ((S.Mapped[Self.Value, _Same[S.Element[Self.Value]]] == Self.Value) if conforms_to(Self.Value, _ResultType) else True) and _ErrorCompatible[_EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], G.MapError[S.Traversed[G, Self.Value, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]]]], C.Failure] and G.Element[C.Result] == Bool and G.Element[_TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True].Out] == Optional[_ListElement[G.Element[_TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True].Out]]] and _CarrierCompatible[G, C.Result] and S.TargetCompatible[G, Self.Value, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]:
        """Retain elements accepted by an effectful borrowing Bool predicate.

        Parameters:
            C: The borrowing library callback type.
            S: The Traversable source family, preserving its native shape and origins.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect containing original elements whose effectful Bool predicate succeeds with True; False discards an element and target failure follows the effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_then[S, G, Self.Value, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]], _EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], G.MapError[S.Traversed[G, Self.Value, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]]]]](_TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True](function^), self.value^, _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]()))

    def filter_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, S: Traversable & FunctorFilter, G: Applicative, F: _Borrowing[P, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], G.MapError[S.Traversed[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]]]] -> Piped[G.Mapped[S.Traversed[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]]] where S.Element[Self.Value] == downcast[P, Movable & Deinitable] and ((S.Mapped[Self.Value, _Same[S.Element[Self.Value]]] == Self.Value) if conforms_to(Self.Value, _ResultType) else True) and _ErrorCompatible[_EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], G.MapError[S.Traversed[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]]]], Never] and G.Element[R] == Bool and G.Element[_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True].Out] == Optional[_ListElement[G.Element[_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True].Out]]] and _CarrierCompatible[G, R] and S.TargetCompatible[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]:
        """Retain elements accepted by an effectful borrowing Bool predicate."""
        return Piped(_traverse_then[S, G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]], _EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], G.MapError[S.Traversed[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), self.value^, _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]()))

    def filter_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, S: Traversable & FunctorFilter, G: Applicative, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], G.MapError[S.Traversed[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]]]] -> Piped[G.Mapped[S.Traversed[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]]] where S.Element[Self.Value] == downcast[P, Movable & Deinitable] and ((S.Mapped[Self.Value, _Same[S.Element[Self.Value]]] == Self.Value) if conforms_to(Self.Value, _ResultType) else True) and _ErrorCompatible[_EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], G.MapError[S.Traversed[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]]]], E] and G.Element[R] == Bool and G.Element[_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True].Out] == Optional[_ListElement[G.Element[_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True].Out]]] and _CarrierCompatible[G, R] and S.TargetCompatible[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]:
        """Retain elements accepted by an effectful borrowing Bool predicate."""
        return Piped(_traverse_then[S, G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]], _EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], G.MapError[S.Traversed[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), self.value^, _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]()))

    def sequence_filter[S: Traversable & FunctorFilter, G: Applicative, X: AnyType = _InferError](deinit self) raises _EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _Same[S.Element[Self.Value]]], G.MapError[S.Traversed[G, Self.Value, _Same[S.Element[Self.Value]]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _Same[S.Element[Self.Value]]]]]]]] -> Piped[G.Mapped[S.Traversed[G, Self.Value, _Same[S.Element[Self.Value]]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _Same[S.Element[Self.Value]]]]]]] where S.Element[Self.Value] == S.Element[Self.Value] and ((S.Mapped[Self.Value, _Same[S.Element[Self.Value]]] == Self.Value) if conforms_to(Self.Value, _ResultType) else True) and _ErrorCompatible[_EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _Same[S.Element[Self.Value]]], G.MapError[S.Traversed[G, Self.Value, _Same[S.Element[Self.Value]]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _Same[S.Element[Self.Value]]]]]]]], Never] and G.Element[_Same[S.Element[Self.Value]].Out] == Optional[_ListElement[G.Element[_Same[S.Element[Self.Value]].Out]]] and _CarrierCompatible[G, _Same[S.Element[Self.Value]].Out] and S.TargetCompatible[G, Self.Value, _Same[S.Element[Self.Value]]]:
        """Traverse effects and retain present Optional payloads inside the effect.

        Parameters:
            S: The Traversable source family, preserving its native shape and origins.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Returns:
            The target effect containing present Optional payloads in source shape, using identity traverse_filter; effect failure remains distinct from discarded absence.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_then[S, G, Self.Value, _Same[S.Element[Self.Value]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _Same[S.Element[Self.Value]]]]], _EntryError[X, _CommonError[S.TraverseError[G, Self.Value, _Same[S.Element[Self.Value]]], G.MapError[S.Traversed[G, Self.Value, _Same[S.Element[Self.Value]]], _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _Same[S.Element[Self.Value]]]]]]]]](_Same[S.Element[Self.Value]](), self.value^, _CompactAfter[S, G.Element[S.Traversed[G, Self.Value, _Same[S.Element[Self.Value]]]]]()))

    def traverse_void[F: UnaryContract & Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, G._LoopError[List[F.Arg], F, _Discard[G.Element[F.Out]]]] -> Piped[G._Looped[List[F.Arg], F, _Discard[G.Element[F.Out]]]] where Self.Value == List[F.Arg] and _CarrierCompatible[G, F.Out] and G._LoopCompatible[List[F.Arg], F, _Discard[G.Element[F.Out]]]:
        """Traverse effects without retaining successful outputs.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect of NoneType, without an output collection. A Piped Result source instead preserves its stored error inside Result[NoneType, E] in that effect. Target failures follow the effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_void[List[F.Arg], F, G, _EntryError[X, G._LoopError[List[F.Arg], F, _Discard[G.Element[F.Out]]]]](function^, rebind_var[List[F.Arg]](self.value^)))

    def traverse_void[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, F: _Unary[A, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, G._LoopError[List[A], _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]] -> Piped[G._Looped[List[A], _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]] where Self.Value == List[A] and _CarrierCompatible[G, R] and G._LoopCompatible[List[A], _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]:
        """Traverse effects without retaining successful outputs."""
        return Piped(_traverse_void[List[A], _NativeUnaryRef[A, R, Never, F, False, o], G, _EntryError[X, G._LoopError[List[A], _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), rebind_var[List[A]](self.value^)))

    def traverse_void[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, G._LoopError[List[A], _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]] -> Piped[G._Looped[List[A], _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]] where Self.Value == List[A] and _CarrierCompatible[G, R] and G._LoopCompatible[List[A], _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]:
        """Traverse effects without retaining successful outputs."""
        return Piped(_traverse_void[List[A], _NativeUnaryRef[A, R, E, F, True, o], G, _EntryError[X, G._LoopError[List[A], _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), rebind_var[List[A]](self.value^)))

    def traverse_tap[C: BorrowCallContract & Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self, var function: C) raises _EntryError[X, ListFamily.TraverseError[G, List[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]]] -> Piped[ListFamily.Traversed[G, List[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]]] where Self.Value == List[downcast[C.Payload, Movable & Deinitable]] and _CarrierCompatible[G, C.Result] and ListFamily.TargetCompatible[G, List[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]]:
        """Traverse effects and retain the original payloads on success.

        Parameters:
            C: The borrowing library callback type.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect containing the original payloads; Piped preserves source shape and Iter/direct calls gather a List.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_as[ListFamily, G, List[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C], _EntryError[X, ListFamily.TraverseError[G, List[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]]]](_TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C](function^), rebind_var[List[downcast[C.Payload, Movable & Deinitable]]](self.value^)))

    def traverse_tap[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, F: _Borrowing[P, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, ListFamily.TraverseError[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]]] -> Piped[ListFamily.Traversed[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]]] where Self.Value == List[downcast[P, Movable & Deinitable]] and _CarrierCompatible[G, R] and ListFamily.TargetCompatible[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]]:
        """Traverse effects and retain the original payloads on success."""
        return Piped(_traverse_as[ListFamily, G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]], _EntryError[X, ListFamily.TraverseError[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[List[downcast[P, Movable & Deinitable]]](self.value^)))

    def traverse_tap[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, ListFamily.TraverseError[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]]] -> Piped[ListFamily.Traversed[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]]] where Self.Value == List[downcast[P, Movable & Deinitable]] and _CarrierCompatible[G, R] and ListFamily.TargetCompatible[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]]:
        """Traverse effects and retain the original payloads on success."""
        return Piped(_traverse_as[ListFamily, G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]], _EntryError[X, ListFamily.TraverseError[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[List[downcast[P, Movable & Deinitable]]](self.value^)))

    def sequence_void[T: Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self) raises _EntryError[X, G._LoopError[List[T], _Same[T], _Discard[G.Element[_Same[T].Out]]]] -> Piped[G._Looped[List[T], _Same[T], _Discard[G.Element[_Same[T].Out]]]] where Self.Value == List[T] and _CarrierCompatible[G, _Same[T].Out] and G._LoopCompatible[List[T], _Same[T], _Discard[G.Element[_Same[T].Out]]]:
        """Traverse effects without retaining successful outputs.

        Parameters:
            T: The element type, including its native origins.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Returns:
            The target effect of NoneType, or of Result[NoneType, E] for a Piped Result source; existing source errors stay inside the target effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_void[List[T], _Same[T], G, _EntryError[X, G._LoopError[List[T], _Same[T], _Discard[G.Element[_Same[T].Out]]]]](_Same[T](), rebind_var[List[T]](self.value^)))

    def flat_traverse[F: UnaryContract & Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, List[F.Arg], F], G.MapError[ListFamily.Traversed[G, List[F.Arg], F], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[F.Arg], F]]]]]] -> Piped[G.Mapped[ListFamily.Traversed[G, List[F.Arg], F], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[F.Arg], F]]]]] where Self.Value == List[F.Arg] and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, List[F.Arg], F], G.MapError[ListFamily.Traversed[G, List[F.Arg], F], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[F.Arg], F]]]]]], F.Error] and G.Element[F.Out] == List[ListFamily.Element[G.Element[F.Out]]] and _CarrierCompatible[G, F.Out] and ListFamily.TargetCompatible[G, List[F.Arg], F]:
        """Traverse effects and flatten one source-family layer inside the effect.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect containing the flattened source shape. The callback produces a target effect of the same source family.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_then[ListFamily, G, List[F.Arg], F, _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[F.Arg], F]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, List[F.Arg], F], G.MapError[ListFamily.Traversed[G, List[F.Arg], F], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[F.Arg], F]]]]]]](function^, rebind_var[List[F.Arg]](self.value^), _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[F.Arg], F]]]()))

    def flat_traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, F: _Unary[A, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]]]]]]] -> Piped[G.Mapped[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]]]]]] where Self.Value == List[A] and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]]]]]]], Never] and G.Element[R] == List[ListFamily.Element[G.Element[R]]] and _CarrierCompatible[G, R] and ListFamily.TargetCompatible[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]]:
        """Traverse effects and flatten one source-family layer inside the effect."""
        return Piped(_traverse_then[ListFamily, G, List[A], _NativeUnaryRef[A, R, Never, F, False, o], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]]]]]]]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), rebind_var[List[A]](self.value^), _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]]]]()))

    def flat_traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]]]]]]] -> Piped[G.Mapped[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]]]]]] where Self.Value == List[A] and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]]]]]]], E] and G.Element[R] == List[ListFamily.Element[G.Element[R]]] and _CarrierCompatible[G, R] and ListFamily.TargetCompatible[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]]:
        """Traverse effects and flatten one source-family layer inside the effect."""
        return Piped(_traverse_then[ListFamily, G, List[A], _NativeUnaryRef[A, R, E, F, True, o], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]]]]]]]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), rebind_var[List[A]](self.value^), _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]]]]()))

    def flat_sequence[T: Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, List[T], _Same[T]], G.MapError[ListFamily.Traversed[G, List[T], _Same[T]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[T], _Same[T]]]]]]] -> Piped[G.Mapped[ListFamily.Traversed[G, List[T], _Same[T]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[T], _Same[T]]]]]] where Self.Value == List[T] and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, List[T], _Same[T]], G.MapError[ListFamily.Traversed[G, List[T], _Same[T]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[T], _Same[T]]]]]]], Never] and G.Element[_Same[T].Out] == List[ListFamily.Element[G.Element[_Same[T].Out]]] and _CarrierCompatible[G, _Same[T].Out] and ListFamily.TargetCompatible[G, List[T], _Same[T]]:
        """Traverse effects and flatten one source-family layer inside the effect.

        Parameters:
            T: The element type, including its native origins.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Returns:
            The target effect containing the source shape after sequencing effects and flattening one source-family layer.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_then[ListFamily, G, List[T], _Same[T], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[T], _Same[T]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, List[T], _Same[T]], G.MapError[ListFamily.Traversed[G, List[T], _Same[T]], _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[T], _Same[T]]]]]]]](_Same[T](), rebind_var[List[T]](self.value^), _FlattenAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[T], _Same[T]]]]()))

    def traverse_filter[F: UnaryContract & Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, List[F.Arg], F], G.MapError[ListFamily.Traversed[G, List[F.Arg], F], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[F.Arg], F]]]]]] -> Piped[G.Mapped[ListFamily.Traversed[G, List[F.Arg], F], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[F.Arg], F]]]]] where Self.Value == List[F.Arg] and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, List[F.Arg], F], G.MapError[ListFamily.Traversed[G, List[F.Arg], F], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[F.Arg], F]]]]]], F.Error] and G.Element[F.Out] == Optional[_ListElement[G.Element[F.Out]]] and _CarrierCompatible[G, F.Out] and ListFamily.TargetCompatible[G, List[F.Arg], F]:
        """Traverse effects and retain present Optional payloads inside the effect.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect containing present Optional results in source shape; absence discards an element and target failure follows the effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_then[ListFamily, G, List[F.Arg], F, _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[F.Arg], F]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, List[F.Arg], F], G.MapError[ListFamily.Traversed[G, List[F.Arg], F], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[F.Arg], F]]]]]]](function^, rebind_var[List[F.Arg]](self.value^), _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[F.Arg], F]]]()))

    def traverse_filter[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, F: _Unary[A, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]]]]]]] -> Piped[G.Mapped[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]]]]]] where Self.Value == List[A] and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]]]]]]], Never] and G.Element[R] == Optional[_ListElement[G.Element[R]]] and _CarrierCompatible[G, R] and ListFamily.TargetCompatible[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]]:
        """Traverse effects and retain present Optional payloads inside the effect."""
        return Piped(_traverse_then[ListFamily, G, List[A], _NativeUnaryRef[A, R, Never, F, False, o], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]]]]]]]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), rebind_var[List[A]](self.value^), _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, Never, F, False, o]]]]()))

    def traverse_filter[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]]]]]]] -> Piped[G.Mapped[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]]]]]] where Self.Value == List[A] and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]]]]]]], E] and G.Element[R] == Optional[_ListElement[G.Element[R]]] and _CarrierCompatible[G, R] and ListFamily.TargetCompatible[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]]:
        """Traverse effects and retain present Optional payloads inside the effect."""
        return Piped(_traverse_then[ListFamily, G, List[A], _NativeUnaryRef[A, R, E, F, True, o], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]]]]]]]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), rebind_var[List[A]](self.value^), _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[A], _NativeUnaryRef[A, R, E, F, True, o]]]]()))

    def filter_effect[C: BorrowCallContract & Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self, var function: C) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, List[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], G.MapError[ListFamily.Traversed[G, List[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]]]] -> Piped[G.Mapped[ListFamily.Traversed[G, List[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]]] where Self.Value == List[downcast[C.Payload, Movable & Deinitable]] and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, List[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], G.MapError[ListFamily.Traversed[G, List[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]]]], C.Failure] and G.Element[C.Result] == Bool and G.Element[_TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True].Out] == Optional[_ListElement[G.Element[_TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True].Out]]] and _CarrierCompatible[G, C.Result] and ListFamily.TargetCompatible[G, List[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]:
        """Retain elements accepted by an effectful borrowing Bool predicate.

        Parameters:
            C: The borrowing library callback type.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect containing original elements whose effectful Bool predicate succeeds with True; False discards an element and target failure follows the effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_then[ListFamily, G, List[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, List[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], G.MapError[ListFamily.Traversed[G, List[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]]]]](_TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True](function^), rebind_var[List[downcast[C.Payload, Movable & Deinitable]]](self.value^), _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]()))

    def filter_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, F: _Borrowing[P, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], G.MapError[ListFamily.Traversed[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]]]] -> Piped[G.Mapped[ListFamily.Traversed[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]]] where Self.Value == List[downcast[P, Movable & Deinitable]] and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], G.MapError[ListFamily.Traversed[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]]]], Never] and G.Element[R] == Bool and G.Element[_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True].Out] == Optional[_ListElement[G.Element[_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True].Out]]] and _CarrierCompatible[G, R] and ListFamily.TargetCompatible[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]:
        """Retain elements accepted by an effectful borrowing Bool predicate."""
        return Piped(_traverse_then[ListFamily, G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], G.MapError[ListFamily.Traversed[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[List[downcast[P, Movable & Deinitable]]](self.value^), _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]()))

    def filter_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], G.MapError[ListFamily.Traversed[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]]]] -> Piped[G.Mapped[ListFamily.Traversed[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]]] where Self.Value == List[downcast[P, Movable & Deinitable]] and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], G.MapError[ListFamily.Traversed[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]]]], E] and G.Element[R] == Bool and G.Element[_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True].Out] == Optional[_ListElement[G.Element[_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True].Out]]] and _CarrierCompatible[G, R] and ListFamily.TargetCompatible[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]:
        """Retain elements accepted by an effectful borrowing Bool predicate."""
        return Piped(_traverse_then[ListFamily, G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], G.MapError[ListFamily.Traversed[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[List[downcast[P, Movable & Deinitable]]](self.value^), _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]()))

    def sequence_filter[T: Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self) raises _EntryError[X, _CommonError[ListFamily.TraverseError[G, List[T], _Same[T]], G.MapError[ListFamily.Traversed[G, List[T], _Same[T]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[T], _Same[T]]]]]]] -> Piped[G.Mapped[ListFamily.Traversed[G, List[T], _Same[T]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[T], _Same[T]]]]]] where Self.Value == List[T] and _ErrorCompatible[_EntryError[X, _CommonError[ListFamily.TraverseError[G, List[T], _Same[T]], G.MapError[ListFamily.Traversed[G, List[T], _Same[T]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[T], _Same[T]]]]]]], Never] and G.Element[_Same[T].Out] == Optional[_ListElement[G.Element[_Same[T].Out]]] and _CarrierCompatible[G, _Same[T].Out] and ListFamily.TargetCompatible[G, List[T], _Same[T]]:
        """Traverse effects and retain present Optional payloads inside the effect.

        Parameters:
            T: The element type, including its native origins.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Returns:
            The target effect containing present Optional payloads in source shape, using identity traverse_filter; effect failure remains distinct from discarded absence.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_then[ListFamily, G, List[T], _Same[T], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[T], _Same[T]]]], _EntryError[X, _CommonError[ListFamily.TraverseError[G, List[T], _Same[T]], G.MapError[ListFamily.Traversed[G, List[T], _Same[T]], _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[T], _Same[T]]]]]]]](_Same[T](), rebind_var[List[T]](self.value^), _CompactAfter[ListFamily, G.Element[ListFamily.Traversed[G, List[T], _Same[T]]]]()))

    def traverse_void[F: UnaryContract & Movable & Deinitable, N: Int, //, G: Applicative, X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, G._LoopError[List[F.Arg], F, _Discard[G.Element[F.Out]]]] -> Piped[G._Looped[List[F.Arg], F, _Discard[G.Element[F.Out]]]] where Self.Value == Array[F.Arg, N] and _CarrierCompatible[G, F.Out] and G._LoopCompatible[List[F.Arg], F, _Discard[G.Element[F.Out]]]:
        """Traverse effects without retaining successful outputs.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            N: The native array length, preserved by mapping.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect of NoneType, without an output collection. A Piped Result source instead preserves its stored error inside Result[NoneType, E] in that effect. Target failures follow the effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_void[List[F.Arg], F, G, _EntryError[X, G._LoopError[List[F.Arg], F, _Discard[G.Element[F.Out]]]]](function^, _take_array(rebind_var[Array[F.Arg, N]](self.value^))))

    def traverse_void[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, G: Applicative, F: _Unary[A, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, G._LoopError[List[A], _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]] -> Piped[G._Looped[List[A], _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]] where Self.Value == Array[A, N] and _CarrierCompatible[G, R] and G._LoopCompatible[List[A], _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]:
        """Traverse effects without retaining successful outputs."""
        return Piped(_traverse_void[List[A], _NativeUnaryRef[A, R, Never, F, False, o], G, _EntryError[X, G._LoopError[List[A], _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), _take_array(rebind_var[Array[A, N]](self.value^))))

    def traverse_void[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, N: Int, //, G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, G._LoopError[List[A], _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]] -> Piped[G._Looped[List[A], _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]] where Self.Value == Array[A, N] and _CarrierCompatible[G, R] and G._LoopCompatible[List[A], _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]:
        """Traverse effects without retaining successful outputs."""
        return Piped(_traverse_void[List[A], _NativeUnaryRef[A, R, E, F, True, o], G, _EntryError[X, G._LoopError[List[A], _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), _take_array(rebind_var[Array[A, N]](self.value^))))

    def sequence_void[T: Movable & Deinitable, N: Int, //, G: Applicative, X: AnyType = _InferError](deinit self) raises _EntryError[X, G._LoopError[List[T], _Same[T], _Discard[G.Element[_Same[T].Out]]]] -> Piped[G._Looped[List[T], _Same[T], _Discard[G.Element[_Same[T].Out]]]] where Self.Value == Array[T, N] and _CarrierCompatible[G, _Same[T].Out] and G._LoopCompatible[List[T], _Same[T], _Discard[G.Element[_Same[T].Out]]]:
        """Traverse effects without retaining successful outputs.

        Parameters:
            T: The element type, including its native origins.
            N: The native array length, preserved by mapping.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Returns:
            The target effect of NoneType, or of Result[NoneType, E] for a Piped Result source; existing source errors stay inside the target effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_void[List[T], _Same[T], G, _EntryError[X, G._LoopError[List[T], _Same[T], _Discard[G.Element[_Same[T].Out]]]]](_Same[T](), _take_array(rebind_var[Array[T, N]](self.value^))))

    def traverse_void[F: UnaryContract & Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, G._LoopError[Deque[F.Arg], F, _Discard[G.Element[F.Out]]]] -> Piped[G._Looped[Deque[F.Arg], F, _Discard[G.Element[F.Out]]]] where Self.Value == Deque[F.Arg] and _CarrierCompatible[G, F.Out] and G._LoopCompatible[Deque[F.Arg], F, _Discard[G.Element[F.Out]]]:
        """Traverse effects without retaining successful outputs.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect of NoneType, without an output collection. A Piped Result source instead preserves its stored error inside Result[NoneType, E] in that effect. Target failures follow the effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_void[Deque[F.Arg], F, G, _EntryError[X, G._LoopError[Deque[F.Arg], F, _Discard[G.Element[F.Out]]]]](function^, rebind_var[Deque[F.Arg]](self.value^)))

    def traverse_void[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, F: _Unary[A, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, G._LoopError[Deque[A], _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]] -> Piped[G._Looped[Deque[A], _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]] where Self.Value == Deque[A] and _CarrierCompatible[G, R] and G._LoopCompatible[Deque[A], _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]:
        """Traverse effects without retaining successful outputs."""
        return Piped(_traverse_void[Deque[A], _NativeUnaryRef[A, R, Never, F, False, o], G, _EntryError[X, G._LoopError[Deque[A], _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), rebind_var[Deque[A]](self.value^)))

    def traverse_void[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, G._LoopError[Deque[A], _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]] -> Piped[G._Looped[Deque[A], _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]] where Self.Value == Deque[A] and _CarrierCompatible[G, R] and G._LoopCompatible[Deque[A], _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]:
        """Traverse effects without retaining successful outputs."""
        return Piped(_traverse_void[Deque[A], _NativeUnaryRef[A, R, E, F, True, o], G, _EntryError[X, G._LoopError[Deque[A], _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), rebind_var[Deque[A]](self.value^)))

    def sequence_void[T: Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self) raises _EntryError[X, G._LoopError[Deque[T], _Same[T], _Discard[G.Element[_Same[T].Out]]]] -> Piped[G._Looped[Deque[T], _Same[T], _Discard[G.Element[_Same[T].Out]]]] where Self.Value == Deque[T] and _CarrierCompatible[G, _Same[T].Out] and G._LoopCompatible[Deque[T], _Same[T], _Discard[G.Element[_Same[T].Out]]]:
        """Traverse effects without retaining successful outputs.

        Parameters:
            T: The element type, including its native origins.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Returns:
            The target effect of NoneType, or of Result[NoneType, E] for a Piped Result source; existing source errors stay inside the target effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_void[Deque[T], _Same[T], G, _EntryError[X, G._LoopError[Deque[T], _Same[T], _Discard[G.Element[_Same[T].Out]]]]](_Same[T](), rebind_var[Deque[T]](self.value^)))

    def traverse_void[F: UnaryContract & Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, G._LoopError[LinkedList[F.Arg], F, _Discard[G.Element[F.Out]]]] -> Piped[G._Looped[LinkedList[F.Arg], F, _Discard[G.Element[F.Out]]]] where Self.Value == LinkedList[F.Arg] and _CarrierCompatible[G, F.Out] and G._LoopCompatible[LinkedList[F.Arg], F, _Discard[G.Element[F.Out]]]:
        """Traverse effects without retaining successful outputs.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect of NoneType, without an output collection. A Piped Result source instead preserves its stored error inside Result[NoneType, E] in that effect. Target failures follow the effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_void[LinkedList[F.Arg], F, G, _EntryError[X, G._LoopError[LinkedList[F.Arg], F, _Discard[G.Element[F.Out]]]]](function^, rebind_var[LinkedList[F.Arg]](self.value^)))

    def traverse_void[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, F: _Unary[A, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, G._LoopError[LinkedList[A], _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]] -> Piped[G._Looped[LinkedList[A], _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]] where Self.Value == LinkedList[A] and _CarrierCompatible[G, R] and G._LoopCompatible[LinkedList[A], _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]:
        """Traverse effects without retaining successful outputs."""
        return Piped(_traverse_void[LinkedList[A], _NativeUnaryRef[A, R, Never, F, False, o], G, _EntryError[X, G._LoopError[LinkedList[A], _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), rebind_var[LinkedList[A]](self.value^)))

    def traverse_void[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, G._LoopError[LinkedList[A], _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]] -> Piped[G._Looped[LinkedList[A], _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]] where Self.Value == LinkedList[A] and _CarrierCompatible[G, R] and G._LoopCompatible[LinkedList[A], _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]:
        """Traverse effects without retaining successful outputs."""
        return Piped(_traverse_void[LinkedList[A], _NativeUnaryRef[A, R, E, F, True, o], G, _EntryError[X, G._LoopError[LinkedList[A], _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), rebind_var[LinkedList[A]](self.value^)))

    def sequence_void[T: Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self) raises _EntryError[X, G._LoopError[LinkedList[T], _Same[T], _Discard[G.Element[_Same[T].Out]]]] -> Piped[G._Looped[LinkedList[T], _Same[T], _Discard[G.Element[_Same[T].Out]]]] where Self.Value == LinkedList[T] and _CarrierCompatible[G, _Same[T].Out] and G._LoopCompatible[LinkedList[T], _Same[T], _Discard[G.Element[_Same[T].Out]]]:
        """Traverse effects without retaining successful outputs.

        Parameters:
            T: The element type, including its native origins.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Returns:
            The target effect of NoneType, or of Result[NoneType, E] for a Piped Result source; existing source errors stay inside the target effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_void[LinkedList[T], _Same[T], G, _EntryError[X, G._LoopError[LinkedList[T], _Same[T], _Discard[G.Element[_Same[T].Out]]]]](_Same[T](), rebind_var[LinkedList[T]](self.value^)))

    def traverse_void[F: UnaryContract & Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, G._LoopError[Optional[F.Arg], F, _Discard[G.Element[F.Out]]]] -> Piped[G._Looped[Optional[F.Arg], F, _Discard[G.Element[F.Out]]]] where Self.Value == Optional[F.Arg] and _CarrierCompatible[G, F.Out] and G._LoopCompatible[Optional[F.Arg], F, _Discard[G.Element[F.Out]]]:
        """Traverse effects without retaining successful outputs.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect of NoneType, without an output collection. A Piped Result source instead preserves its stored error inside Result[NoneType, E] in that effect. Target failures follow the effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_void[Optional[F.Arg], F, G, _EntryError[X, G._LoopError[Optional[F.Arg], F, _Discard[G.Element[F.Out]]]]](function^, rebind_var[Optional[F.Arg]](self.value^)))

    def traverse_void[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, F: _Unary[A, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, G._LoopError[Optional[A], _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]] -> Piped[G._Looped[Optional[A], _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]] where Self.Value == Optional[A] and _CarrierCompatible[G, R] and G._LoopCompatible[Optional[A], _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]:
        """Traverse effects without retaining successful outputs."""
        return Piped(_traverse_void[Optional[A], _NativeUnaryRef[A, R, Never, F, False, o], G, _EntryError[X, G._LoopError[Optional[A], _NativeUnaryRef[A, R, Never, F, False, o], _Discard[G.Element[_NativeUnaryRef[A, R, Never, F, False, o].Out]]]]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), rebind_var[Optional[A]](self.value^)))

    def traverse_void[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, G._LoopError[Optional[A], _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]] -> Piped[G._Looped[Optional[A], _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]] where Self.Value == Optional[A] and _CarrierCompatible[G, R] and G._LoopCompatible[Optional[A], _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]:
        """Traverse effects without retaining successful outputs."""
        return Piped(_traverse_void[Optional[A], _NativeUnaryRef[A, R, E, F, True, o], G, _EntryError[X, G._LoopError[Optional[A], _NativeUnaryRef[A, R, E, F, True, o], _Discard[G.Element[_NativeUnaryRef[A, R, E, F, True, o].Out]]]]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), rebind_var[Optional[A]](self.value^)))

    def traverse_tap[C: BorrowCallContract & Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self, var function: C) raises _EntryError[X, OptionalFamily.TraverseError[G, Optional[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]]] -> Piped[OptionalFamily.Traversed[G, Optional[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]]] where Self.Value == Optional[downcast[C.Payload, Movable & Deinitable]] and _CarrierCompatible[G, C.Result] and OptionalFamily.TargetCompatible[G, Optional[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]]:
        """Traverse effects and retain the original payloads on success.

        Parameters:
            C: The borrowing library callback type.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect containing the original payloads; Piped preserves source shape and Iter/direct calls gather a List.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_as[OptionalFamily, G, Optional[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C], _EntryError[X, OptionalFamily.TraverseError[G, Optional[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]]]](_TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C](function^), rebind_var[Optional[downcast[C.Payload, Movable & Deinitable]]](self.value^)))

    def traverse_tap[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, F: _Borrowing[P, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, OptionalFamily.TraverseError[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]]] -> Piped[OptionalFamily.Traversed[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]]] where Self.Value == Optional[downcast[P, Movable & Deinitable]] and _CarrierCompatible[G, R] and OptionalFamily.TargetCompatible[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]]:
        """Traverse effects and retain the original payloads on success."""
        return Piped(_traverse_as[OptionalFamily, G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]], _EntryError[X, OptionalFamily.TraverseError[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[Optional[downcast[P, Movable & Deinitable]]](self.value^)))

    def traverse_tap[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, OptionalFamily.TraverseError[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]]] -> Piped[OptionalFamily.Traversed[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]]] where Self.Value == Optional[downcast[P, Movable & Deinitable]] and _CarrierCompatible[G, R] and OptionalFamily.TargetCompatible[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]]:
        """Traverse effects and retain the original payloads on success."""
        return Piped(_traverse_as[OptionalFamily, G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]], _EntryError[X, OptionalFamily.TraverseError[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[Optional[downcast[P, Movable & Deinitable]]](self.value^)))

    def sequence_void[T: Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self) raises _EntryError[X, G._LoopError[Optional[T], _Same[T], _Discard[G.Element[_Same[T].Out]]]] -> Piped[G._Looped[Optional[T], _Same[T], _Discard[G.Element[_Same[T].Out]]]] where Self.Value == Optional[T] and _CarrierCompatible[G, _Same[T].Out] and G._LoopCompatible[Optional[T], _Same[T], _Discard[G.Element[_Same[T].Out]]]:
        """Traverse effects without retaining successful outputs.

        Parameters:
            T: The element type, including its native origins.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Returns:
            The target effect of NoneType, or of Result[NoneType, E] for a Piped Result source; existing source errors stay inside the target effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_void[Optional[T], _Same[T], G, _EntryError[X, G._LoopError[Optional[T], _Same[T], _Discard[G.Element[_Same[T].Out]]]]](_Same[T](), rebind_var[Optional[T]](self.value^)))

    def flat_traverse[F: UnaryContract & Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[F.Arg], F], G.MapError[OptionalFamily.Traversed[G, Optional[F.Arg], F], _FlattenAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[F.Arg], F]]]]]] -> Piped[G.Mapped[OptionalFamily.Traversed[G, Optional[F.Arg], F], _FlattenAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[F.Arg], F]]]]] where Self.Value == Optional[F.Arg] and _ErrorCompatible[_EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[F.Arg], F], G.MapError[OptionalFamily.Traversed[G, Optional[F.Arg], F], _FlattenAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[F.Arg], F]]]]]], F.Error] and G.Element[F.Out] == Optional[OptionalFamily.Element[G.Element[F.Out]]] and _CarrierCompatible[G, F.Out] and OptionalFamily.TargetCompatible[G, Optional[F.Arg], F]:
        """Traverse effects and flatten one source-family layer inside the effect.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect containing the flattened source shape. The callback produces a target effect of the same source family.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_then[OptionalFamily, G, Optional[F.Arg], F, _FlattenAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[F.Arg], F]]], _EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[F.Arg], F], G.MapError[OptionalFamily.Traversed[G, Optional[F.Arg], F], _FlattenAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[F.Arg], F]]]]]]](function^, rebind_var[Optional[F.Arg]](self.value^), _FlattenAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[F.Arg], F]]]()))

    def flat_traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, F: _Unary[A, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]]]]]]] -> Piped[G.Mapped[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]]]]]] where Self.Value == Optional[A] and _ErrorCompatible[_EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]]]]]]], Never] and G.Element[R] == Optional[OptionalFamily.Element[G.Element[R]]] and _CarrierCompatible[G, R] and OptionalFamily.TargetCompatible[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]]:
        """Traverse effects and flatten one source-family layer inside the effect."""
        return Piped(_traverse_then[OptionalFamily, G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o], _FlattenAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]]]], _EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]]]]]]]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), rebind_var[Optional[A]](self.value^), _FlattenAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]]]]()))

    def flat_traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]]]]]]] -> Piped[G.Mapped[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]]]]]] where Self.Value == Optional[A] and _ErrorCompatible[_EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]]]]]]], E] and G.Element[R] == Optional[OptionalFamily.Element[G.Element[R]]] and _CarrierCompatible[G, R] and OptionalFamily.TargetCompatible[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]]:
        """Traverse effects and flatten one source-family layer inside the effect."""
        return Piped(_traverse_then[OptionalFamily, G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o], _FlattenAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]]]], _EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]]]]]]]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), rebind_var[Optional[A]](self.value^), _FlattenAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]]]]()))

    def flat_sequence[T: Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self) raises _EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[T], _Same[T]], G.MapError[OptionalFamily.Traversed[G, Optional[T], _Same[T]], _FlattenAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[T], _Same[T]]]]]]] -> Piped[G.Mapped[OptionalFamily.Traversed[G, Optional[T], _Same[T]], _FlattenAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[T], _Same[T]]]]]] where Self.Value == Optional[T] and _ErrorCompatible[_EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[T], _Same[T]], G.MapError[OptionalFamily.Traversed[G, Optional[T], _Same[T]], _FlattenAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[T], _Same[T]]]]]]], Never] and G.Element[_Same[T].Out] == Optional[OptionalFamily.Element[G.Element[_Same[T].Out]]] and _CarrierCompatible[G, _Same[T].Out] and OptionalFamily.TargetCompatible[G, Optional[T], _Same[T]]:
        """Traverse effects and flatten one source-family layer inside the effect.

        Parameters:
            T: The element type, including its native origins.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Returns:
            The target effect containing the source shape after sequencing effects and flattening one source-family layer.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_then[OptionalFamily, G, Optional[T], _Same[T], _FlattenAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[T], _Same[T]]]], _EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[T], _Same[T]], G.MapError[OptionalFamily.Traversed[G, Optional[T], _Same[T]], _FlattenAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[T], _Same[T]]]]]]]](_Same[T](), rebind_var[Optional[T]](self.value^), _FlattenAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[T], _Same[T]]]]()))

    def traverse_filter[F: UnaryContract & Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[F.Arg], F], G.MapError[OptionalFamily.Traversed[G, Optional[F.Arg], F], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[F.Arg], F]]]]]] -> Piped[G.Mapped[OptionalFamily.Traversed[G, Optional[F.Arg], F], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[F.Arg], F]]]]] where Self.Value == Optional[F.Arg] and _ErrorCompatible[_EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[F.Arg], F], G.MapError[OptionalFamily.Traversed[G, Optional[F.Arg], F], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[F.Arg], F]]]]]], F.Error] and G.Element[F.Out] == Optional[_ListElement[G.Element[F.Out]]] and _CarrierCompatible[G, F.Out] and OptionalFamily.TargetCompatible[G, Optional[F.Arg], F]:
        """Traverse effects and retain present Optional payloads inside the effect.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect containing present Optional results in source shape; absence discards an element and target failure follows the effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_then[OptionalFamily, G, Optional[F.Arg], F, _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[F.Arg], F]]], _EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[F.Arg], F], G.MapError[OptionalFamily.Traversed[G, Optional[F.Arg], F], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[F.Arg], F]]]]]]](function^, rebind_var[Optional[F.Arg]](self.value^), _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[F.Arg], F]]]()))

    def traverse_filter[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, F: _Unary[A, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]]]]]]] -> Piped[G.Mapped[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]]]]]] where Self.Value == Optional[A] and _ErrorCompatible[_EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]]]]]]], Never] and G.Element[R] == Optional[_ListElement[G.Element[R]]] and _CarrierCompatible[G, R] and OptionalFamily.TargetCompatible[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]]:
        """Traverse effects and retain present Optional payloads inside the effect."""
        return Piped(_traverse_then[OptionalFamily, G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]]]], _EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]]]]]]]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), rebind_var[Optional[A]](self.value^), _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, Never, F, False, o]]]]()))

    def traverse_filter[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]]]]]]] -> Piped[G.Mapped[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]]]]]] where Self.Value == Optional[A] and _ErrorCompatible[_EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]]]]]]], E] and G.Element[R] == Optional[_ListElement[G.Element[R]]] and _CarrierCompatible[G, R] and OptionalFamily.TargetCompatible[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]]:
        """Traverse effects and retain present Optional payloads inside the effect."""
        return Piped(_traverse_then[OptionalFamily, G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]]]], _EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]]]]]]]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), rebind_var[Optional[A]](self.value^), _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[A], _NativeUnaryRef[A, R, E, F, True, o]]]]()))

    def filter_effect[C: BorrowCallContract & Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self, var function: C) raises _EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], G.MapError[OptionalFamily.Traversed[G, Optional[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]]]] -> Piped[G.Mapped[OptionalFamily.Traversed[G, Optional[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]]] where Self.Value == Optional[downcast[C.Payload, Movable & Deinitable]] and _ErrorCompatible[_EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], G.MapError[OptionalFamily.Traversed[G, Optional[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]]]], C.Failure] and G.Element[C.Result] == Bool and G.Element[_TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True].Out] == Optional[_ListElement[G.Element[_TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True].Out]]] and _CarrierCompatible[G, C.Result] and OptionalFamily.TargetCompatible[G, Optional[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]:
        """Retain elements accepted by an effectful borrowing Bool predicate.

        Parameters:
            C: The borrowing library callback type.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect containing original elements whose effectful Bool predicate succeeds with True; False discards an element and target failure follows the effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_then[OptionalFamily, G, Optional[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]], _EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], G.MapError[OptionalFamily.Traversed[G, Optional[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]]]]](_TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True](function^), rebind_var[Optional[downcast[C.Payload, Movable & Deinitable]]](self.value^), _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[downcast[C.Payload, Movable & Deinitable]], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C, True]]]]()))

    def filter_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, F: _Borrowing[P, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], G.MapError[OptionalFamily.Traversed[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]]]] -> Piped[G.Mapped[OptionalFamily.Traversed[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]]] where Self.Value == Optional[downcast[P, Movable & Deinitable]] and _ErrorCompatible[_EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], G.MapError[OptionalFamily.Traversed[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]]]], Never] and G.Element[R] == Bool and G.Element[_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True].Out] == Optional[_ListElement[G.Element[_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True].Out]]] and _CarrierCompatible[G, R] and OptionalFamily.TargetCompatible[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]:
        """Retain elements accepted by an effectful borrowing Bool predicate."""
        return Piped(_traverse_then[OptionalFamily, G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]], _EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], G.MapError[OptionalFamily.Traversed[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[Optional[downcast[P, Movable & Deinitable]]](self.value^), _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o], True]]]]()))

    def filter_effect[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, //, G: Applicative, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], G.MapError[OptionalFamily.Traversed[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]]]] -> Piped[G.Mapped[OptionalFamily.Traversed[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]]] where Self.Value == Optional[downcast[P, Movable & Deinitable]] and _ErrorCompatible[_EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], G.MapError[OptionalFamily.Traversed[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]]]], E] and G.Element[R] == Bool and G.Element[_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True].Out] == Optional[_ListElement[G.Element[_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True].Out]]] and _CarrierCompatible[G, R] and OptionalFamily.TargetCompatible[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]:
        """Retain elements accepted by an effectful borrowing Bool predicate."""
        return Piped(_traverse_then[OptionalFamily, G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]], _EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], G.MapError[OptionalFamily.Traversed[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[Optional[downcast[P, Movable & Deinitable]]](self.value^), _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[downcast[P, Movable & Deinitable]], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o], True]]]]()))

    def sequence_filter[T: Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self) raises _EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[T], _Same[T]], G.MapError[OptionalFamily.Traversed[G, Optional[T], _Same[T]], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[T], _Same[T]]]]]]] -> Piped[G.Mapped[OptionalFamily.Traversed[G, Optional[T], _Same[T]], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[T], _Same[T]]]]]] where Self.Value == Optional[T] and _ErrorCompatible[_EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[T], _Same[T]], G.MapError[OptionalFamily.Traversed[G, Optional[T], _Same[T]], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[T], _Same[T]]]]]]], Never] and G.Element[_Same[T].Out] == Optional[_ListElement[G.Element[_Same[T].Out]]] and _CarrierCompatible[G, _Same[T].Out] and OptionalFamily.TargetCompatible[G, Optional[T], _Same[T]]:
        """Traverse effects and retain present Optional payloads inside the effect.

        Parameters:
            T: The element type, including its native origins.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Returns:
            The target effect containing present Optional payloads in source shape, using identity traverse_filter; effect failure remains distinct from discarded absence.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_then[OptionalFamily, G, Optional[T], _Same[T], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[T], _Same[T]]]], _EntryError[X, _CommonError[OptionalFamily.TraverseError[G, Optional[T], _Same[T]], G.MapError[OptionalFamily.Traversed[G, Optional[T], _Same[T]], _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[T], _Same[T]]]]]]]](_Same[T](), rebind_var[Optional[T]](self.value^), _CompactAfter[OptionalFamily, G.Element[OptionalFamily.Traversed[G, Optional[T], _Same[T]]]]()))

    def traverse_void[F: UnaryContract & Movable & Deinitable, Failure: Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, ResultFamily[Failure].TraverseError[G, Result[F.Arg, Failure], Composition[False, 1, F, _EffectVoid[G, F.Out]]]] -> Piped[ResultFamily[Failure].Traversed[G, Result[F.Arg, Failure], Composition[False, 1, F, _EffectVoid[G, F.Out]]]] where Self.Value == Result[F.Arg, Failure] and _CarrierCompatible[G, F.Out] and ResultFamily[Failure].TargetCompatible[G, Result[F.Arg, Failure], Composition[False, 1, F, _EffectVoid[G, F.Out]]]:
        """Traverse effects without retaining successful outputs.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            Failure: The error payload type retained by Result.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect of NoneType, without an output collection. A Piped Result source instead preserves its stored error inside Result[NoneType, E] in that effect. Target failures follow the effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_as[ResultFamily[Failure], G, Result[F.Arg, Failure], Composition[False, 1, F, _EffectVoid[G, F.Out]], _EntryError[X, ResultFamily[Failure].TraverseError[G, Result[F.Arg, Failure], Composition[False, 1, F, _EffectVoid[G, F.Out]]]]](Composition[False, 1, F, _EffectVoid[G, F.Out]](function^, _EffectVoid[G, F.Out]()), rebind_var[Result[F.Arg, Failure]](self.value^)))

    def traverse_void[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, Failure: Movable & Deinitable, //, G: Applicative, F: _Unary[A, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, ResultFamily[Failure].TraverseError[G, Result[A, Failure], Composition[False, 1, _NativeUnaryRef[A, R, Never, F, False, o], _EffectVoid[G, _NativeUnaryRef[A, R, Never, F, False, o].Out]]]] -> Piped[ResultFamily[Failure].Traversed[G, Result[A, Failure], Composition[False, 1, _NativeUnaryRef[A, R, Never, F, False, o], _EffectVoid[G, _NativeUnaryRef[A, R, Never, F, False, o].Out]]]] where Self.Value == Result[A, Failure] and _CarrierCompatible[G, R] and ResultFamily[Failure].TargetCompatible[G, Result[A, Failure], Composition[False, 1, _NativeUnaryRef[A, R, Never, F, False, o], _EffectVoid[G, _NativeUnaryRef[A, R, Never, F, False, o].Out]]]:
        """Traverse effects without retaining successful outputs."""
        return Piped(_traverse_as[ResultFamily[Failure], G, Result[A, Failure], Composition[False, 1, _NativeUnaryRef[A, R, Never, F, False, o], _EffectVoid[G, _NativeUnaryRef[A, R, Never, F, False, o].Out]], _EntryError[X, ResultFamily[Failure].TraverseError[G, Result[A, Failure], Composition[False, 1, _NativeUnaryRef[A, R, Never, F, False, o], _EffectVoid[G, _NativeUnaryRef[A, R, Never, F, False, o].Out]]]]](Composition[False, 1, _NativeUnaryRef[A, R, Never, F, False, o], _EffectVoid[G, _NativeUnaryRef[A, R, Never, F, False, o].Out]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), _EffectVoid[G, _NativeUnaryRef[A, R, Never, F, False, o].Out]()), rebind_var[Result[A, Failure]](self.value^)))

    def traverse_void[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, Failure: Movable & Deinitable, //, G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, ResultFamily[Failure].TraverseError[G, Result[A, Failure], Composition[False, 1, _NativeUnaryRef[A, R, E, F, True, o], _EffectVoid[G, _NativeUnaryRef[A, R, E, F, True, o].Out]]]] -> Piped[ResultFamily[Failure].Traversed[G, Result[A, Failure], Composition[False, 1, _NativeUnaryRef[A, R, E, F, True, o], _EffectVoid[G, _NativeUnaryRef[A, R, E, F, True, o].Out]]]] where Self.Value == Result[A, Failure] and _CarrierCompatible[G, R] and ResultFamily[Failure].TargetCompatible[G, Result[A, Failure], Composition[False, 1, _NativeUnaryRef[A, R, E, F, True, o], _EffectVoid[G, _NativeUnaryRef[A, R, E, F, True, o].Out]]]:
        """Traverse effects without retaining successful outputs."""
        return Piped(_traverse_as[ResultFamily[Failure], G, Result[A, Failure], Composition[False, 1, _NativeUnaryRef[A, R, E, F, True, o], _EffectVoid[G, _NativeUnaryRef[A, R, E, F, True, o].Out]], _EntryError[X, ResultFamily[Failure].TraverseError[G, Result[A, Failure], Composition[False, 1, _NativeUnaryRef[A, R, E, F, True, o], _EffectVoid[G, _NativeUnaryRef[A, R, E, F, True, o].Out]]]]](Composition[False, 1, _NativeUnaryRef[A, R, E, F, True, o], _EffectVoid[G, _NativeUnaryRef[A, R, E, F, True, o].Out]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), _EffectVoid[G, _NativeUnaryRef[A, R, E, F, True, o].Out]()), rebind_var[Result[A, Failure]](self.value^)))

    def traverse_tap[C: BorrowCallContract & Movable & Deinitable, Failure: Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self, var function: C) raises _EntryError[X, ResultFamily[Failure].TraverseError[G, Result[downcast[C.Payload, Movable & Deinitable], Failure], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]]] -> Piped[ResultFamily[Failure].Traversed[G, Result[downcast[C.Payload, Movable & Deinitable], Failure], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]]] where Self.Value == Result[downcast[C.Payload, Movable & Deinitable], Failure] and _CarrierCompatible[G, C.Result] and ResultFamily[Failure].TargetCompatible[G, Result[downcast[C.Payload, Movable & Deinitable], Failure], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]]:
        """Traverse effects and retain the original payloads on success.

        Parameters:
            C: The borrowing library callback type.
            Failure: The error payload type retained by Result.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect containing the original payloads; Piped preserves source shape and Iter/direct calls gather a List.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_as[ResultFamily[Failure], G, Result[downcast[C.Payload, Movable & Deinitable], Failure], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C], _EntryError[X, ResultFamily[Failure].TraverseError[G, Result[downcast[C.Payload, Movable & Deinitable], Failure], _TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C]]]](_TraverseTap[downcast[C.Payload, Movable & Deinitable], G, C](function^), rebind_var[Result[downcast[C.Payload, Movable & Deinitable], Failure]](self.value^)))

    def traverse_tap[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Failure: Movable & Deinitable, //, G: Applicative, F: _Borrowing[P, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, ResultFamily[Failure].TraverseError[G, Result[downcast[P, Movable & Deinitable], Failure], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]]] -> Piped[ResultFamily[Failure].Traversed[G, Result[downcast[P, Movable & Deinitable], Failure], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]]] where Self.Value == Result[downcast[P, Movable & Deinitable], Failure] and _CarrierCompatible[G, R] and ResultFamily[Failure].TargetCompatible[G, Result[downcast[P, Movable & Deinitable], Failure], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]]:
        """Traverse effects and retain the original payloads on success."""
        return Piped(_traverse_as[ResultFamily[Failure], G, Result[downcast[P, Movable & Deinitable], Failure], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]], _EntryError[X, ResultFamily[Failure].TraverseError[G, Result[downcast[P, Movable & Deinitable], Failure], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, Never, F, False, o]](_NativeBorrowRef[P, R, Never, F, False, o](Pointer(to=function))), rebind_var[Result[downcast[P, Movable & Deinitable], Failure]](self.value^)))

    def traverse_tap[P: AnyType, R: Movable & Deinitable, o: ImmOrigin, Failure: Movable & Deinitable, //, G: Applicative, E: Movable & Deinitable, F: _RaisingBorrowing[P, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, ResultFamily[Failure].TraverseError[G, Result[downcast[P, Movable & Deinitable], Failure], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]]] -> Piped[ResultFamily[Failure].Traversed[G, Result[downcast[P, Movable & Deinitable], Failure], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]]] where Self.Value == Result[downcast[P, Movable & Deinitable], Failure] and _CarrierCompatible[G, R] and ResultFamily[Failure].TargetCompatible[G, Result[downcast[P, Movable & Deinitable], Failure], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]]:
        """Traverse effects and retain the original payloads on success."""
        return Piped(_traverse_as[ResultFamily[Failure], G, Result[downcast[P, Movable & Deinitable], Failure], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]], _EntryError[X, ResultFamily[Failure].TraverseError[G, Result[downcast[P, Movable & Deinitable], Failure], _TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]]]]](_TraverseTap[downcast[P, Movable & Deinitable], G, _NativeBorrowRef[P, R, E, F, True, o]](_NativeBorrowRef[P, R, E, F, True, o](Pointer(to=function))), rebind_var[Result[downcast[P, Movable & Deinitable], Failure]](self.value^)))

    def sequence_void[T: Movable & Deinitable, Failure: Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self) raises _EntryError[X, ResultFamily[Failure].TraverseError[G, Result[T, Failure], Composition[False, 1, _Same[T], _EffectVoid[G, _Same[T].Out]]]] -> Piped[ResultFamily[Failure].Traversed[G, Result[T, Failure], Composition[False, 1, _Same[T], _EffectVoid[G, _Same[T].Out]]]] where Self.Value == Result[T, Failure] and _CarrierCompatible[G, _Same[T].Out] and ResultFamily[Failure].TargetCompatible[G, Result[T, Failure], Composition[False, 1, _Same[T], _EffectVoid[G, _Same[T].Out]]]:
        """Traverse effects without retaining successful outputs.

        Parameters:
            T: The element type, including its native origins.
            Failure: The error payload type retained by Result.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Returns:
            The target effect of NoneType, or of Result[NoneType, E] for a Piped Result source; existing source errors stay inside the target effect.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_as[ResultFamily[Failure], G, Result[T, Failure], Composition[False, 1, _Same[T], _EffectVoid[G, _Same[T].Out]], _EntryError[X, ResultFamily[Failure].TraverseError[G, Result[T, Failure], Composition[False, 1, _Same[T], _EffectVoid[G, _Same[T].Out]]]]](Composition[False, 1, _Same[T], _EffectVoid[G, _Same[T].Out]](_Same[T](), _EffectVoid[G, _Same[T].Out]()), rebind_var[Result[T, Failure]](self.value^)))

    def flat_traverse[F: UnaryContract & Movable & Deinitable, Failure: Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self, var function: F) raises _EntryError[X, _CommonError[ResultFamily[Failure].TraverseError[G, Result[F.Arg, Failure], F], G.MapError[ResultFamily[Failure].Traversed[G, Result[F.Arg, Failure], F], _FlattenAfter[ResultFamily[Failure], G.Element[ResultFamily[Failure].Traversed[G, Result[F.Arg, Failure], F]]]]]] -> Piped[G.Mapped[ResultFamily[Failure].Traversed[G, Result[F.Arg, Failure], F], _FlattenAfter[ResultFamily[Failure], G.Element[ResultFamily[Failure].Traversed[G, Result[F.Arg, Failure], F]]]]] where Self.Value == Result[F.Arg, Failure] and _ErrorCompatible[_EntryError[X, _CommonError[ResultFamily[Failure].TraverseError[G, Result[F.Arg, Failure], F], G.MapError[ResultFamily[Failure].Traversed[G, Result[F.Arg, Failure], F], _FlattenAfter[ResultFamily[Failure], G.Element[ResultFamily[Failure].Traversed[G, Result[F.Arg, Failure], F]]]]]], F.Error] and G.Element[F.Out] == Result[ResultFamily[Failure].Element[G.Element[F.Out]], Failure] and _CarrierCompatible[G, F.Out] and ResultFamily[Failure].TargetCompatible[G, Result[F.Arg, Failure], F]:
        """Traverse effects and flatten one source-family layer inside the effect.

        Parameters:
            F: The callback type, retaining its receiver, captures and error contract.
            Failure: The error payload type retained by Result.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Args:
            function: The callback, consumed; calls follow the operation's evaluation order.

        Returns:
            The target effect containing the flattened source shape. The callback produces a target effect of the same source family.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_then[ResultFamily[Failure], G, Result[F.Arg, Failure], F, _FlattenAfter[ResultFamily[Failure], G.Element[ResultFamily[Failure].Traversed[G, Result[F.Arg, Failure], F]]], _EntryError[X, _CommonError[ResultFamily[Failure].TraverseError[G, Result[F.Arg, Failure], F], G.MapError[ResultFamily[Failure].Traversed[G, Result[F.Arg, Failure], F], _FlattenAfter[ResultFamily[Failure], G.Element[ResultFamily[Failure].Traversed[G, Result[F.Arg, Failure], F]]]]]]](function^, rebind_var[Result[F.Arg, Failure]](self.value^), _FlattenAfter[ResultFamily[Failure], G.Element[ResultFamily[Failure].Traversed[G, Result[F.Arg, Failure], F]]]()))

    def flat_traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, Failure: Movable & Deinitable, //, G: Applicative, F: _Unary[A, R], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[ResultFamily[Failure].TraverseError[G, Result[A, Failure], _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ResultFamily[Failure].Traversed[G, Result[A, Failure], _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[ResultFamily[Failure], G.Element[ResultFamily[Failure].Traversed[G, Result[A, Failure], _NativeUnaryRef[A, R, Never, F, False, o]]]]]]] -> Piped[G.Mapped[ResultFamily[Failure].Traversed[G, Result[A, Failure], _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[ResultFamily[Failure], G.Element[ResultFamily[Failure].Traversed[G, Result[A, Failure], _NativeUnaryRef[A, R, Never, F, False, o]]]]]] where Self.Value == Result[A, Failure] and _ErrorCompatible[_EntryError[X, _CommonError[ResultFamily[Failure].TraverseError[G, Result[A, Failure], _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ResultFamily[Failure].Traversed[G, Result[A, Failure], _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[ResultFamily[Failure], G.Element[ResultFamily[Failure].Traversed[G, Result[A, Failure], _NativeUnaryRef[A, R, Never, F, False, o]]]]]]], Never] and G.Element[R] == Result[ResultFamily[Failure].Element[G.Element[R]], Failure] and _CarrierCompatible[G, R] and ResultFamily[Failure].TargetCompatible[G, Result[A, Failure], _NativeUnaryRef[A, R, Never, F, False, o]]:
        """Traverse effects and flatten one source-family layer inside the effect."""
        return Piped(_traverse_then[ResultFamily[Failure], G, Result[A, Failure], _NativeUnaryRef[A, R, Never, F, False, o], _FlattenAfter[ResultFamily[Failure], G.Element[ResultFamily[Failure].Traversed[G, Result[A, Failure], _NativeUnaryRef[A, R, Never, F, False, o]]]], _EntryError[X, _CommonError[ResultFamily[Failure].TraverseError[G, Result[A, Failure], _NativeUnaryRef[A, R, Never, F, False, o]], G.MapError[ResultFamily[Failure].Traversed[G, Result[A, Failure], _NativeUnaryRef[A, R, Never, F, False, o]], _FlattenAfter[ResultFamily[Failure], G.Element[ResultFamily[Failure].Traversed[G, Result[A, Failure], _NativeUnaryRef[A, R, Never, F, False, o]]]]]]]](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), rebind_var[Result[A, Failure]](self.value^), _FlattenAfter[ResultFamily[Failure], G.Element[ResultFamily[Failure].Traversed[G, Result[A, Failure], _NativeUnaryRef[A, R, Never, F, False, o]]]]()))

    def flat_traverse[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, Failure: Movable & Deinitable, //, G: Applicative, E: Movable & Deinitable, F: _RaisingUnary[A, R, E], X: AnyType = _InferError](deinit self, ref[o] function: F) raises _EntryError[X, _CommonError[ResultFamily[Failure].TraverseError[G, Result[A, Failure], _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[ResultFamily[Failure].Traversed[G, Result[A, Failure], _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[ResultFamily[Failure], G.Element[ResultFamily[Failure].Traversed[G, Result[A, Failure], _NativeUnaryRef[A, R, E, F, True, o]]]]]]] -> Piped[G.Mapped[ResultFamily[Failure].Traversed[G, Result[A, Failure], _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[ResultFamily[Failure], G.Element[ResultFamily[Failure].Traversed[G, Result[A, Failure], _NativeUnaryRef[A, R, E, F, True, o]]]]]] where Self.Value == Result[A, Failure] and _ErrorCompatible[_EntryError[X, _CommonError[ResultFamily[Failure].TraverseError[G, Result[A, Failure], _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[ResultFamily[Failure].Traversed[G, Result[A, Failure], _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[ResultFamily[Failure], G.Element[ResultFamily[Failure].Traversed[G, Result[A, Failure], _NativeUnaryRef[A, R, E, F, True, o]]]]]]], E] and G.Element[R] == Result[ResultFamily[Failure].Element[G.Element[R]], Failure] and _CarrierCompatible[G, R] and ResultFamily[Failure].TargetCompatible[G, Result[A, Failure], _NativeUnaryRef[A, R, E, F, True, o]]:
        """Traverse effects and flatten one source-family layer inside the effect."""
        return Piped(_traverse_then[ResultFamily[Failure], G, Result[A, Failure], _NativeUnaryRef[A, R, E, F, True, o], _FlattenAfter[ResultFamily[Failure], G.Element[ResultFamily[Failure].Traversed[G, Result[A, Failure], _NativeUnaryRef[A, R, E, F, True, o]]]], _EntryError[X, _CommonError[ResultFamily[Failure].TraverseError[G, Result[A, Failure], _NativeUnaryRef[A, R, E, F, True, o]], G.MapError[ResultFamily[Failure].Traversed[G, Result[A, Failure], _NativeUnaryRef[A, R, E, F, True, o]], _FlattenAfter[ResultFamily[Failure], G.Element[ResultFamily[Failure].Traversed[G, Result[A, Failure], _NativeUnaryRef[A, R, E, F, True, o]]]]]]]](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), rebind_var[Result[A, Failure]](self.value^), _FlattenAfter[ResultFamily[Failure], G.Element[ResultFamily[Failure].Traversed[G, Result[A, Failure], _NativeUnaryRef[A, R, E, F, True, o]]]]()))

    def flat_sequence[T: Movable & Deinitable, Failure: Movable & Deinitable, //, G: Applicative, X: AnyType = _InferError](deinit self) raises _EntryError[X, _CommonError[ResultFamily[Failure].TraverseError[G, Result[T, Failure], _Same[T]], G.MapError[ResultFamily[Failure].Traversed[G, Result[T, Failure], _Same[T]], _FlattenAfter[ResultFamily[Failure], G.Element[ResultFamily[Failure].Traversed[G, Result[T, Failure], _Same[T]]]]]]] -> Piped[G.Mapped[ResultFamily[Failure].Traversed[G, Result[T, Failure], _Same[T]], _FlattenAfter[ResultFamily[Failure], G.Element[ResultFamily[Failure].Traversed[G, Result[T, Failure], _Same[T]]]]]] where Self.Value == Result[T, Failure] and _ErrorCompatible[_EntryError[X, _CommonError[ResultFamily[Failure].TraverseError[G, Result[T, Failure], _Same[T]], G.MapError[ResultFamily[Failure].Traversed[G, Result[T, Failure], _Same[T]], _FlattenAfter[ResultFamily[Failure], G.Element[ResultFamily[Failure].Traversed[G, Result[T, Failure], _Same[T]]]]]]], Never] and G.Element[_Same[T].Out] == Result[ResultFamily[Failure].Element[G.Element[_Same[T].Out]], Failure] and _CarrierCompatible[G, _Same[T].Out] and ResultFamily[Failure].TargetCompatible[G, Result[T, Failure], _Same[T]]:
        """Traverse effects and flatten one source-family layer inside the effect.

        Parameters:
            T: The element type, including its native origins.
            Failure: The error payload type retained by Result.
            G: The target Applicative family; it determines effect sequencing and failure.
            X: The exact native error type; traversal can supply it as generic evidence, which is checked without converting errors.

        Returns:
            The target effect containing the source shape after sequencing effects and flattening one source-family layer.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        return Piped(_traverse_then[ResultFamily[Failure], G, Result[T, Failure], _Same[T], _FlattenAfter[ResultFamily[Failure], G.Element[ResultFamily[Failure].Traversed[G, Result[T, Failure], _Same[T]]]], _EntryError[X, _CommonError[ResultFamily[Failure].TraverseError[G, Result[T, Failure], _Same[T]], G.MapError[ResultFamily[Failure].Traversed[G, Result[T, Failure], _Same[T]], _FlattenAfter[ResultFamily[Failure], G.Element[ResultFamily[Failure].Traversed[G, Result[T, Failure], _Same[T]]]]]]]](_Same[T](), rebind_var[Result[T, Failure]](self.value^), _FlattenAfter[ResultFamily[Failure], G.Element[ResultFamily[Failure].Traversed[G, Result[T, Failure], _Same[T]]]]()))

    # --- end container methods ---

    def fold_left[A: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(var A, var T) -> A](
        deinit self, step: F, var initial: A
    ) -> Piped[A] where _Source[Self.Value].Element == T:
        """Fold immediately and continue the chain with the accumulator.

        The step receives the accumulator and each element in source order.
        Empty input returns the initial accumulator without calling the step.

        Parameters:
            A: The accumulator type.
            T: The source element type.
            F: The step's type: a non-raising plain function or closure.

        Args:
            step: The step, borrowed for this call.
            initial: The initial accumulator, consumed without copying.

        Returns:
            A chain holding the final accumulator.
        """
        return Piped(_fold_left(step, initial^, self.value^))

    def fold_left[A: Movable & Deinitable, T: Movable & Deinitable, //,
            E: AnyType, F: def(var A, var T) raises E -> A](
        deinit self, step: F, var initial: A
    ) raises E -> Piped[A] where _Source[Self.Value].Element == T:
        """Fold immediately with a raising step, keeping its exact error type.

        Generic forwarding states the error explicitly as `fold_left[E=E]`.
        Failure stops further pulls and destroys the remaining owned state.

        Parameters:
            A: The accumulator type.
            T: The source element type.
            E: The step's exact error type.
            F: The step's type: a raising plain function or closure.

        Args:
            step: The step, borrowed for this call.
            initial: The initial accumulator, consumed without copying.

        Returns:
            A chain holding the final accumulator.

        Raises:
            The step's exact error; no later element is pulled or stage run.
        """
        return Piped(_fold_left[E=E](step, initial^, self.value^))

    def fold_left[A: Movable & Deinitable, F: Binary](
        deinit self, step: F, var initial: A
    ) raises F.Error -> Piped[A] where F.First == A and F.Second == _Source[Self.Value].Element and F.Out == A:
        """Fold immediately with a library `Binary` step and its exact error."""
        return Piped(_fold_left(step, initial^, self.value^))

    def fold_left[A: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](
        deinit self, var step: F, var initial: A
    ) raises F.Error -> Piped[A] where F.First == A and F.Second == _Source[Self.Value].Element and F.Out == A and RepeatableBinary[F]:
        """Consume a repeatable step and fold through its mutable or shared receiver.

        Parameters:
            A: The accumulator type, preserved at each step.
            F: A shared or mutable binary callback with matching operand types.

        Args:
            step: The callback owner, consumed. Pass `mut_ref(step)` to retain its state.
            initial: The initial accumulator, consumed.

        Returns:
            A Piped accumulator after the source is exhausted.

        Raises:
            The callback's exact error; failure stops before another pull.
        """
        return Piped(_fold_left(step^, initial^, self.value^))

    def get(deinit self) -> Self.Value:
        """End the chain and return the value.

        Returns:
            The value the chain holds, moved out.
        """
        return self.value^


def piped[T: Movable & Deinitable](var value: T) -> Piped[T]:
    """Start an eager chained pipeline: `piped(value).then(f).then(g).get()`.

    The chain returns `g(f(value))`. Each stage runs once, when its `then` is
    called, so a chain has no limit on its length, and closures need no
    `as_unary`. Unlike `pipe`, the stages need not share one error type: each
    `then` raises its own.

    Parameters:
        T: The input type.

    Args:
        value: The input, consumed.

    Returns:
        A chain holding `value`.
    """
    return Piped[T](value^)


struct _ImmediateRunner(_PipelineRunner):
    @staticmethod
    def apply[index: Int, R: Movable & Deinitable, E: Movable & Deinitable,
              A: Movable & Deinitable, *Environment: Movable & Deinitable](
        var value: A, *environment: *Environment
    ) raises E -> R:
        comptime assert _check_stage[index, Environment[index], A, R, E]()
        return _stage_shared[R, E](environment[index], value^)



def pipe[A: Movable & Deinitable, //,
         Results: TypeList[Trait=Movable & Deinitable, ...],
         E: Movable & Deinitable = Never, *Fs: Movable & Deinitable](
    var value: A, *functions: *Fs
) raises E -> _PipelineResult[A, Results]:
    """Apply stages with every result type stated: `pipe[Results, E](value, *stages)`."""
    comptime if Results.length != Fs.length:
        comptime assert False, "pipe: one result type is required per stage"
    elif Fs.length == 0:
        comptime assert _PipelineResult[A, Results] == A
        return rebind_var[_PipelineResult[A, Results]](value^)
    else:
        comptime assert _PipelineResult[A, Results] == Results[Results.length - 1]
        return rebind_var[_PipelineResult[A, Results]](
            _pipe_at[0, Results, E, _ImmediateRunner](value^, *functions)
        )


def pipe[A: Movable & Deinitable, //,
         E: Movable & Deinitable, *Fs: Movable & Deinitable](
    var value: A, *functions: *Fs
) raises E -> _PipelineResult[A, _Plan[*Fs].Results] where Fs.length >= 2:
    """Apply stages with their common error stated: `pipe[E=Failure](value, *stages)`."""
    return pipe[_Plan[*Fs].Results, E](value^, *functions)


# Mojo 1.2 ranks an unconstrained pack ahead of fixed thin signatures. Admit
# the inferred pack only for the library stages that its planner can inspect.
def pipe[A: Movable & Deinitable, //, *Fs: Movable & Deinitable](
    var value: A, *functions: *Fs
) raises _Plan[*Fs].Failure -> _PipelineResult[A, _Plan[*Fs].Results] where Fs.length >= 2 and Fs.all_conforms_to[Unary]():
    """Apply stages to `value` left to right and return the last result.

    Each stage runs once, in order, and receives the previous stage's result as
    an owned value; tuples and `Result` values pass whole. Two to eight plain
    functions are accepted as they are, `pipe(value, parse, check, render)`;
    library values such as partials and compositions, and closures promoted
    with `as_unary`, are accepted in any number. A stage whose input is not the
    previous result is a compile error that names the stage. `pipe[E=Failure]`
    states the common error, and `pipe[Results, E]` every result type.

    An inferred two-stage call can mix a plain function or stored thin pointer
    with a shared library stage directly, in either position. The library
    stage is borrowed and remains reusable after the call.

    Limitations:
        At most eight plain functions per call, because Mojo 1.1 cannot read a
        function's signature from a variadic pack: nest calls, group stages
        with `flow`, or chain them with `piped`. Longer mixed calls and explicit
        error/result bindings promote native stages with `as_unary`, as do
        capturing closures in mixed calls. Stages that raise
        different error types are mapped to one type first.

    Parameters:
        A: The input type.
        Fs: The stage types.

    Args:
        value: The input, consumed.
        functions: The stages, borrowed, in the order they run.

    Returns:
        The last stage's result.

    Raises:
        The error type that every raising stage declares; a pipeline of pure
        stages does not raise.
    """
    return pipe[E=_Plan[*Fs].Failure](value^, *functions)


# --- plain-function overloads (generated) ---
# Generated by scripts/generate_plain_overloads.py; edit the generator, not this
# block. A plain function's signature is known only at a parameter of its function
# type; a variadic pack keeps the type but not the signature, so a stage's result
# cannot be inferred from it. Each stage count therefore spells one thin
# signature per stage and delegates to the variadic form. Later stages name their
# own input type (P1, P2, ...), so a mismatched call reaches the per-stage check.
# Closures use as_unary.


def pipe[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, P1: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, //](
    var value: A0, f0: def(var A0) raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2
) raises _CommonError[E0, E1] -> A2:
    """Apply 2 plain functions in order."""
    return pipe[E=_CommonError[E0, E1]](value^, _Thin1F[A0, A1, E0](f0), _Thin1F[P1, A2, E1](f1))


def pipe[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, //](
    var value: A0, f0: def(var A0) raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2, f2: def(var P2) raises E2 thin -> A3
) raises _CommonError[_CommonError[E0, E1], E2] -> A3:
    """Apply 3 plain functions in order."""
    return pipe[E=_CommonError[_CommonError[E0, E1], E2]](value^, _Thin1F[A0, A1, E0](f0), _Thin1F[P1, A2, E1](f1), _Thin1F[P2, A3, E2](f2))


def pipe[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, //](
    var value: A0, f0: def(var A0) raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2, f2: def(var P2) raises E2 thin -> A3, f3: def(var P3) raises E3 thin -> A4
) raises _CommonError[_CommonError[_CommonError[E0, E1], E2], E3] -> A4:
    """Apply 4 plain functions in order."""
    return pipe[E=_CommonError[_CommonError[_CommonError[E0, E1], E2], E3]](value^, _Thin1F[A0, A1, E0](f0), _Thin1F[P1, A2, E1](f1), _Thin1F[P2, A3, E2](f2), _Thin1F[P3, A4, E3](f3))


def pipe[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, //](
    var value: A0, f0: def(var A0) raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2, f2: def(var P2) raises E2 thin -> A3, f3: def(var P3) raises E3 thin -> A4, f4: def(var P4) raises E4 thin -> A5
) raises _CommonError[_CommonError[_CommonError[_CommonError[E0, E1], E2], E3], E4] -> A5:
    """Apply 5 plain functions in order."""
    return pipe[E=_CommonError[_CommonError[_CommonError[_CommonError[E0, E1], E2], E3], E4]](value^, _Thin1F[A0, A1, E0](f0), _Thin1F[P1, A2, E1](f1), _Thin1F[P2, A3, E2](f2), _Thin1F[P3, A4, E3](f3), _Thin1F[P4, A5, E4](f4))


def pipe[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, P5: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, E5: Movable & Deinitable, //](
    var value: A0, f0: def(var A0) raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2, f2: def(var P2) raises E2 thin -> A3, f3: def(var P3) raises E3 thin -> A4, f4: def(var P4) raises E4 thin -> A5, f5: def(var P5) raises E5 thin -> A6
) raises _CommonError[_CommonError[_CommonError[_CommonError[_CommonError[E0, E1], E2], E3], E4], E5] -> A6:
    """Apply 6 plain functions in order."""
    return pipe[E=_CommonError[_CommonError[_CommonError[_CommonError[_CommonError[E0, E1], E2], E3], E4], E5]](value^, _Thin1F[A0, A1, E0](f0), _Thin1F[P1, A2, E1](f1), _Thin1F[P2, A3, E2](f2), _Thin1F[P3, A4, E3](f3), _Thin1F[P4, A5, E4](f4), _Thin1F[P5, A6, E5](f5))


def pipe[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, P5: Movable & Deinitable, P6: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, E5: Movable & Deinitable, E6: Movable & Deinitable, //](
    var value: A0, f0: def(var A0) raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2, f2: def(var P2) raises E2 thin -> A3, f3: def(var P3) raises E3 thin -> A4, f4: def(var P4) raises E4 thin -> A5, f5: def(var P5) raises E5 thin -> A6, f6: def(var P6) raises E6 thin -> A7
) raises _CommonError[_CommonError[_CommonError[_CommonError[_CommonError[_CommonError[E0, E1], E2], E3], E4], E5], E6] -> A7:
    """Apply 7 plain functions in order."""
    return pipe[E=_CommonError[_CommonError[_CommonError[_CommonError[_CommonError[_CommonError[E0, E1], E2], E3], E4], E5], E6]](value^, _Thin1F[A0, A1, E0](f0), _Thin1F[P1, A2, E1](f1), _Thin1F[P2, A3, E2](f2), _Thin1F[P3, A4, E3](f3), _Thin1F[P4, A5, E4](f4), _Thin1F[P5, A6, E5](f5), _Thin1F[P6, A7, E6](f6))


def pipe[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, A8: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, P5: Movable & Deinitable, P6: Movable & Deinitable, P7: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, E5: Movable & Deinitable, E6: Movable & Deinitable, E7: Movable & Deinitable, //](
    var value: A0, f0: def(var A0) raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2, f2: def(var P2) raises E2 thin -> A3, f3: def(var P3) raises E3 thin -> A4, f4: def(var P4) raises E4 thin -> A5, f5: def(var P5) raises E5 thin -> A6, f6: def(var P6) raises E6 thin -> A7, f7: def(var P7) raises E7 thin -> A8
) raises _CommonError[_CommonError[_CommonError[_CommonError[_CommonError[_CommonError[_CommonError[E0, E1], E2], E3], E4], E5], E6], E7] -> A8:
    """Apply 8 plain functions in order."""
    return pipe[E=_CommonError[_CommonError[_CommonError[_CommonError[_CommonError[_CommonError[_CommonError[E0, E1], E2], E3], E4], E5], E6], E7]](value^, _Thin1F[A0, A1, E0](f0), _Thin1F[P1, A2, E1](f1), _Thin1F[P2, A3, E2](f2), _Thin1F[P3, A4, E3](f3), _Thin1F[P4, A5, E4](f4), _Thin1F[P5, A6, E5](f5), _Thin1F[P6, A7, E6](f6), _Thin1F[P7, A8, E7](f7))


def pipe[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, F: Unary, q: ImmOrigin, //](
    var value: V, ref[q] function: def(var A) thin -> R, stage: F
) raises _Plan[NativeUnary[A, R, Never, type_of(function), False], F].Failure -> _Plan[NativeUnary[A, R, Never, type_of(function), False], F].Result:
    """Apply a plain function or stored pointer beside one borrowed library stage."""
    return pipe(value^, NativeUnary[A, R, Never, type_of(function), False](function), stage)


def pipe[V: Movable & Deinitable, A: Movable & Deinitable, R: RegisterPassable & Deinitable, F: Unary, //](
    var value: V, function: def(var A) thin -> R, stage: F
) raises _Plan[NativeUnary[A, R, Never, type_of(function), False], F].Failure -> _Plan[NativeUnary[A, R, Never, type_of(function), False], F].Result where not conforms_to(A, RegisterPassable):
    """Apply a plain function or stored pointer beside one borrowed library stage."""
    return pipe(value^, NativeUnary[A, R, Never, type_of(function), False](function), stage)


def pipe[V: Movable & Deinitable, A: RegisterPassable & Deinitable, R: Movable & Deinitable, F: Unary, //](
    var value: V, function: def(var A) thin -> R, stage: F
) raises _Plan[NativeUnary[A, R, Never, type_of(function), False], F].Failure -> _Plan[NativeUnary[A, R, Never, type_of(function), False], F].Result where not conforms_to(R, RegisterPassable):
    """Apply a plain function or stored pointer beside one borrowed library stage."""
    return pipe(value^, NativeUnary[A, R, Never, type_of(function), False](function), stage)


def pipe[V: Movable & Deinitable, A: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, F: Unary, //](
    var value: V, function: def(var A) thin -> R, stage: F
) raises _Plan[NativeUnary[A, R, Never, type_of(function), False], F].Failure -> _Plan[NativeUnary[A, R, Never, type_of(function), False], F].Result:
    """Apply a plain function or stored pointer beside one borrowed library stage."""
    return pipe(value^, NativeUnary[A, R, Never, type_of(function), False](function), stage)


def pipe[V: Movable & Deinitable, A: Movable & Deinitable, F: Unary, //](
    var value: V, function: def(var A) thin, stage: F
) raises _Plan[NativeUnary[A, type_of(None), Never, type_of(function), False], F].Failure -> _Plan[NativeUnary[A, type_of(None), Never, type_of(function), False], F].Result:
    """Apply a plain function or stored pointer beside one borrowed library stage."""
    return pipe(value^, NativeUnary[A, type_of(None), Never, type_of(function), False](function), stage)


def pipe[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: Unary, q: ImmOrigin, //](
    var value: V, ref[q] function: def(var A) raises X thin -> R, stage: F
) raises _Plan[NativeUnary[A, R, X, type_of(function), True], F].Failure -> _Plan[NativeUnary[A, R, X, type_of(function), True], F].Result:
    """Apply a plain function or stored pointer beside one borrowed library stage."""
    return pipe(value^, NativeUnary[A, R, X, type_of(function), True](function), stage)


def pipe[V: Movable & Deinitable, A: Movable & Deinitable, R: RegisterPassable & Deinitable, X: Movable & Deinitable, F: Unary, //](
    var value: V, function: def(var A) raises X thin -> R, stage: F
) raises _Plan[NativeUnary[A, R, X, type_of(function), True], F].Failure -> _Plan[NativeUnary[A, R, X, type_of(function), True], F].Result where not conforms_to(A, RegisterPassable):
    """Apply a plain function or stored pointer beside one borrowed library stage."""
    return pipe(value^, NativeUnary[A, R, X, type_of(function), True](function), stage)


def pipe[V: Movable & Deinitable, A: RegisterPassable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: Unary, //](
    var value: V, function: def(var A) raises X thin -> R, stage: F
) raises _Plan[NativeUnary[A, R, X, type_of(function), True], F].Failure -> _Plan[NativeUnary[A, R, X, type_of(function), True], F].Result where not conforms_to(R, RegisterPassable):
    """Apply a plain function or stored pointer beside one borrowed library stage."""
    return pipe(value^, NativeUnary[A, R, X, type_of(function), True](function), stage)


def pipe[V: Movable & Deinitable, A: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, X: Movable & Deinitable, F: Unary, //](
    var value: V, function: def(var A) raises X thin -> R, stage: F
) raises _Plan[NativeUnary[A, R, X, type_of(function), True], F].Failure -> _Plan[NativeUnary[A, R, X, type_of(function), True], F].Result:
    """Apply a plain function or stored pointer beside one borrowed library stage."""
    return pipe(value^, NativeUnary[A, R, X, type_of(function), True](function), stage)


def pipe[V: Movable & Deinitable, A: Movable & Deinitable, X: Movable & Deinitable, F: Unary, //](
    var value: V, function: def(var A) raises X thin, stage: F
) raises _Plan[NativeUnary[A, type_of(None), X, type_of(function), True], F].Failure -> _Plan[NativeUnary[A, type_of(None), X, type_of(function), True], F].Result:
    """Apply a plain function or stored pointer beside one borrowed library stage."""
    return pipe(value^, NativeUnary[A, type_of(None), X, type_of(function), True](function), stage)


def pipe[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, F: Unary, q: ImmOrigin, //](
    var value: V, stage: F, ref[q] function: def(var A) thin -> R
) raises _Plan[F, NativeUnary[A, R, Never, type_of(function), False]].Failure -> _Plan[F, NativeUnary[A, R, Never, type_of(function), False]].Result:
    """Apply a plain function or stored pointer beside one borrowed library stage."""
    return pipe(value^, stage, NativeUnary[A, R, Never, type_of(function), False](function))


def pipe[V: Movable & Deinitable, A: Movable & Deinitable, R: RegisterPassable & Deinitable, F: Unary, //](
    var value: V, stage: F, function: def(var A) thin -> R
) raises _Plan[F, NativeUnary[A, R, Never, type_of(function), False]].Failure -> _Plan[F, NativeUnary[A, R, Never, type_of(function), False]].Result where not conforms_to(A, RegisterPassable):
    """Apply a plain function or stored pointer beside one borrowed library stage."""
    return pipe(value^, stage, NativeUnary[A, R, Never, type_of(function), False](function))


def pipe[V: Movable & Deinitable, A: RegisterPassable & Deinitable, R: Movable & Deinitable, F: Unary, //](
    var value: V, stage: F, function: def(var A) thin -> R
) raises _Plan[F, NativeUnary[A, R, Never, type_of(function), False]].Failure -> _Plan[F, NativeUnary[A, R, Never, type_of(function), False]].Result where not conforms_to(R, RegisterPassable):
    """Apply a plain function or stored pointer beside one borrowed library stage."""
    return pipe(value^, stage, NativeUnary[A, R, Never, type_of(function), False](function))


def pipe[V: Movable & Deinitable, A: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, F: Unary, //](
    var value: V, stage: F, function: def(var A) thin -> R
) raises _Plan[F, NativeUnary[A, R, Never, type_of(function), False]].Failure -> _Plan[F, NativeUnary[A, R, Never, type_of(function), False]].Result:
    """Apply a plain function or stored pointer beside one borrowed library stage."""
    return pipe(value^, stage, NativeUnary[A, R, Never, type_of(function), False](function))


def pipe[V: Movable & Deinitable, A: Movable & Deinitable, F: Unary, //](
    var value: V, stage: F, function: def(var A) thin
) raises _Plan[F, NativeUnary[A, type_of(None), Never, type_of(function), False]].Failure -> _Plan[F, NativeUnary[A, type_of(None), Never, type_of(function), False]].Result:
    """Apply a plain function or stored pointer beside one borrowed library stage."""
    return pipe(value^, stage, NativeUnary[A, type_of(None), Never, type_of(function), False](function))


def pipe[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: Unary, q: ImmOrigin, //](
    var value: V, stage: F, ref[q] function: def(var A) raises X thin -> R
) raises _Plan[F, NativeUnary[A, R, X, type_of(function), True]].Failure -> _Plan[F, NativeUnary[A, R, X, type_of(function), True]].Result:
    """Apply a plain function or stored pointer beside one borrowed library stage."""
    return pipe(value^, stage, NativeUnary[A, R, X, type_of(function), True](function))


def pipe[V: Movable & Deinitable, A: Movable & Deinitable, R: RegisterPassable & Deinitable, X: Movable & Deinitable, F: Unary, //](
    var value: V, stage: F, function: def(var A) raises X thin -> R
) raises _Plan[F, NativeUnary[A, R, X, type_of(function), True]].Failure -> _Plan[F, NativeUnary[A, R, X, type_of(function), True]].Result where not conforms_to(A, RegisterPassable):
    """Apply a plain function or stored pointer beside one borrowed library stage."""
    return pipe(value^, stage, NativeUnary[A, R, X, type_of(function), True](function))


def pipe[V: Movable & Deinitable, A: RegisterPassable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, F: Unary, //](
    var value: V, stage: F, function: def(var A) raises X thin -> R
) raises _Plan[F, NativeUnary[A, R, X, type_of(function), True]].Failure -> _Plan[F, NativeUnary[A, R, X, type_of(function), True]].Result where not conforms_to(R, RegisterPassable):
    """Apply a plain function or stored pointer beside one borrowed library stage."""
    return pipe(value^, stage, NativeUnary[A, R, X, type_of(function), True](function))


def pipe[V: Movable & Deinitable, A: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, X: Movable & Deinitable, F: Unary, //](
    var value: V, stage: F, function: def(var A) raises X thin -> R
) raises _Plan[F, NativeUnary[A, R, X, type_of(function), True]].Failure -> _Plan[F, NativeUnary[A, R, X, type_of(function), True]].Result:
    """Apply a plain function or stored pointer beside one borrowed library stage."""
    return pipe(value^, stage, NativeUnary[A, R, X, type_of(function), True](function))


def pipe[V: Movable & Deinitable, A: Movable & Deinitable, X: Movable & Deinitable, F: Unary, //](
    var value: V, stage: F, function: def(var A) raises X thin
) raises _Plan[F, NativeUnary[A, type_of(None), X, type_of(function), True]].Failure -> _Plan[F, NativeUnary[A, type_of(None), X, type_of(function), True]].Result:
    """Apply a plain function or stored pointer beside one borrowed library stage."""
    return pipe(value^, stage, NativeUnary[A, type_of(None), X, type_of(function), True](function))
# --- end plain-function overloads ---
