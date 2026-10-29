"""Static algebra dictionaries: result types are aliases, behavior is in methods.

An instance's associated types name only its own parameters and the types of
the values and callbacks it receives, so naming an instance evaluates no other
operation. Operations are static methods; pure construction additionally has
an associated callable per payload. Public operations and composed families use
that concrete constructor, while existing dictionaries retain the static pure
default. Callbacks use the fixed-arity protocols of `fp.callables`.
"""
from std.builtin.rebind import rebind_var, downcast
from std.iter import IterableOwned, Iterator
from std.builtin.rebind import rebind
# Algebra's retained receiver view shares the callable dispatch used by
# Kleisli. Existing consumers retain their private import name.
from fp.callables._receiver import _MutableUnaryRef as _UnaryView
from fp.callables.protocols import (BorrowCallContract, _ErrorProbe, UnaryContract, BinaryContract, ThunkContract,
                                    Unary, Binary, OnceUnary, MutableUnary, OnceThunk, BorrowCallable)
from fp.callables.invoke import call_once, RepeatableUnary, RepeatableBinary
from fp.callables._receiver import _binary_repeated_as, _unary_repeated_as, _thunk_once_as, _unary_once_as
from fp.iteration._advance import _next_optional, _Source, _source
from fp.iteration._terminal import _append
from fp._internal.errors import _CommonErrorCompatible, _CommonError, _ErrorCompatible, _propagate_error
from fp.callables._identity import Identity
from fp.data._result import _ResultType
from fp.callables._binding import _BindFirst


# Shared wording for family admission that includes receiver requirements.
comptime _CALLBACK_ADMISSION = "family operation requires compatible carriers and callback receivers; branching callbacks must be repeatable"

trait _FamilyCarrier(Movable, Deinitable):
    """Declared carrier metadata, shared by algebra selection and effect recipes.

    A declared family supplies the Functor contract needed by selection.
    This marker owns no execution, admission or storage policy.
    """
    comptime Family: Functor
    comptime Value: Movable & Deinitable


trait Functor:
    """A carrier family whose payload can be transformed without changing its context: `map`.

    Checked free functions and fluent methods require the admission predicates
    in their signatures. Generic wrappers must forward those requirements.
    Dictionary primitives assume admitted types: Mojo 1.1 does not support
    where clauses on trait methods. Input payload and callback argument types
    must also match, including embedded origins.
    """
    comptime Element[V: Movable & Deinitable]: Movable & Deinitable
    """The payload type of a carrier `V` of this family."""
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Bool = True
    """Additional admission for map; generic forwarders preserve this in their where clause."""
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The carrier `map` returns for a carrier `V` and a callback `F`."""
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The error `map` raises for a carrier `V` and a callback `F`."""
    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.MapError[V, F] -> Self.Mapped[V, F]:
        """Transform the payload of `value` with `f`, keeping its context.

        Parameters:
            V: The carrier's type.
            F: The callback's type.

        Args:
            f: The callback, consumed.
            value: The carrier, consumed.

        Returns:
            The carrier of the callback's results.

        Raises:
            The callback's error, and any error the family adds.
        """
        ...


trait RebindingFunctor(Functor):
    """A family whose selection depends on its payload type.

    Ordinary Functors continue with their existing family. Value dictionaries
    implement this capability because native Dict exposes no generic value
    type projection. Rebinding changes selection metadata, never the carrier.
    """
    comptime WithElement[A: Movable & Deinitable]: Functor
    """The same semantic family selected for payload A, retaining other parameters."""


comptime _MappedFamily[I: Functor, A: Movable & Deinitable] = (
    downcast[I, RebindingFunctor].WithElement[A] if conforms_to(I, RebindingFunctor) else I
)


trait ErrorMapping(Functor):
    """Map the success and one selected stored-error channel in one operation.

    This capability is independent of failure construction and recovery.
    A family also implementing ApplicativeError uses the same exact Failure.
    Checked contracts admit source, callbacks and destination before invoking
    bimap; the primitive preserves branch order, ownership and native errors.
    """
    comptime Failure: Movable & Deinitable
    """The selected stored-error type, including its origins."""
    comptime ErrorCarrierCompatible[V: Movable & Deinitable]: Bool
    """Whether V belongs to this family's selected stored-error channel."""
    comptime DefaultErrorTarget[A: Movable & Deinitable, E: Movable & Deinitable]: ErrorMapping
    """The candidate destination for payload A and stored error E; use Self for a fixed policy.

    This projection is explicit: Mojo 1.2 leaves an inherited parameterized
    Self default opaque during ordinary callback inference. Declaring the
    policy in its dictionary preserves inferred end-user calls.
    """
    comptime BimapCompatible[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable]: Bool
    """The source family's admission of this operation and policy transition."""
    comptime Bimapped[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The exact destination carrier produced by the primitive."""
    comptime BimapError[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The exact native construction error; deferred run errors stay in the carrier."""
    @staticmethod
    def bimap[Target: ErrorMapping, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable](
        var on_ok: F, var on_err: G, var source: V
    ) raises Self.BimapError[Target,V,F,G] -> Self.Bimapped[Target,V,F,G]:
        """Transform one original outcome through the admitted destination policy.

        Parameters:
            Target: The destination family, including its error policy.
            V: The source carrier type.
            F: The success callback type.
            G: The stored-error callback type.

        Args:
            on_ok: The consuming success callback.
            on_err: The consuming stored-error callback.
            source: The complete source carrier, consumed once.

        Returns:
            The mapped carrier belonging to Target.

        Raises:
            The exact family construction error, including callback errors.
        """
        ...


trait Filterable:
    """A carrier family that can discard payloads while keeping its context.

    This capability is independent of Functor: removing a value and changing
    its type have different native constraints. Rejected values must be
    representable without inventing a payload or an error. Owned predicates
    have a shared or mutable receiver; `FilterContract` owns their admission.
    The primitive assumes that admission, as other family primitives do.
    """
    comptime Element[V: Movable & Deinitable]: Movable & Deinitable
    """The payload type of a carrier of this family."""
    comptime FilteredFamily: AnyType = Self
    """Family of the filtered carrier; fluent continuation requires a Functor."""
    comptime Filtered[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable]: Movable & Deinitable
    """The carrier returned by filtering; deferred families may change its concrete type."""
    comptime FilterError[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable]: Movable & Deinitable
    """The error raised when constructing the filtered carrier."""
    @staticmethod
    def filter[V: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable](var predicate: P, var value: V
    ) raises Self.FilterError[V, P] -> Self.Filtered[V, P]:
        """Retain payloads accepted by a borrowing Bool predicate.

        Parameters:
            V: The carrier's type.
            P: The repeatable borrowing predicate's type.

        Args:
            predicate: The predicate, consumed; it borrows each payload.
            value: The carrier, consumed.

        Returns:
            A carrier of accepted original payloads, retaining their types and origins.

        Raises:
            The family's filtering error, with its exact native type.
        """
        ...


trait FunctorFilter(Functor):
    """Map to Optional payloads and discard absent results in the same traversal.

    Unlike Filterable, this operation may change the payload type. Fixed-size
    or nonempty carriers need not implement it. Deferred instances keep their
    own evaluation, error and origin semantics.
    """
    comptime MapFilteredFamily: Functor = Self
    """Family of the compacted carrier; may differ when filtering loses shape."""
    comptime MapFiltered[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The carrier of present transformed payloads."""
    comptime MapFilterError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The exact error of constructing the transformed carrier."""
    @staticmethod
    def filter_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.MapFilterError[V, F] -> Self.MapFiltered[V, F]:
        """Consume each payload into f, retaining only present Optional results.

        Parameters:
            V: The consumed source or carrier type.
            F: The callback type, retaining its receiver, captures and error contract.

        Args:
            f: The callback, consumed; calls follow the operation's evaluation order.
            value: The source, consumed with its native origins; iterator sources are not restarted.

        Returns:
            The carrier of present transformed Optional payloads, in source order.

        Raises:
            The exact callback, monoid or family error; Never for a non-raising operation.
        """
        ...


@fieldwise_init
struct _FamilyPure[I: Applicative, A: Movable & Deinitable](Unary, Copyable, Defaultable):
    """Default constructor adapter for existing family dictionaries."""
    comptime Arg = Self.A
    comptime Out = Self.I.Pure[Self.A]
    def call(self, var value: Self.Arg) -> Self.Out:
        return Self.I.pure(value^)


def _pure[I: Applicative, A: Movable & Deinitable](var value: A) -> I.Pure[A]:
    """Invoke the concrete payload constructor with the ordinary pure contract."""
    comptime F = I._PureAction[A]
    comptime assert F.Arg == A and F.Out == I.Pure[A] and F.Error == Never
    return rebind_var[I.Pure[A]](_unary_once_as[Never](F(), rebind_var[F.Arg](value^)))


trait Applicative(Functor):
    """A `Functor` that can introduce a payload (`pure`) and combine independent computations (`map2_lazy`).

    The private `_Joined[L, R]`, `_join_left` and `_join_right` represent either
    of two computations with the same payload. Eager families share one carrier
    type; deferred families override the join to retain the selected computation.
    Transformers and conditional recovery share this boundary without needing bind.
    `_JoinCompatible[L, R]` describes construction admission for that choice;
    deferred execution still validates its actual environment or state at run.

    `collect` gathers every payload a callback produces over a source into a
    `List`, and list traversal into this family uses it. It is the private
    `_loop` with an append rule: one pull loop whose accumulation rule decides
    how payloads combine and when the accumulator stops being live. The default
    `_loop` runs over `pure`, `map` and `map2_lazy` and stops pulling once the
    accumulator has failed. It requires an accumulator type that stays the same
    across steps; a family whose combination changes type overrides the private
    `_Looped`, `_LoopError` and `_loop` with its own single loop.
    """
    # Joining alternative carriers needs no bind. Conditional error recovery
    # uses it for ApplicativeError families such as Validation as well.
    comptime _JoinCompatible[L: Movable & Deinitable, R: Movable & Deinitable]: Bool = L == R
    comptime _Joined[L: Movable & Deinitable, R: Movable & Deinitable]: Movable & Deinitable = L
    @staticmethod
    def _join_left[L: Movable & Deinitable, R: Movable & Deinitable](var value: L) -> Self._Joined[L, R]:
        comptime assert L == R, "choice: branches of an eager family must have one carrier type"
        return rebind_var[Self._Joined[L, R]](value^)
    @staticmethod
    def _join_right[L: Movable & Deinitable, R: Movable & Deinitable](var value: R) -> Self._Joined[L, R]:
        comptime assert L == R, "choice: branches of an eager family must have one carrier type"
        return rebind_var[Self._Joined[L, R]](value^)
    comptime CarrierCompatible[V: Movable & Deinitable]: Bool = (
        Self.MapCompatible[V, Identity[Self.Element[V]]] and
        (V == Self.Pure[Self.Element[V]] if conforms_to(Self.Pure[NoneType], _ResultType) else True)
    )
    """Preserve fixed native Result admission for existing custom dictionaries.

    Families with other carrier shapes override this public predicate.
    Deferred representations need not equal Pure.
    """
    comptime Pure[A: Movable & Deinitable]: Movable & Deinitable
    """The carrier `pure` returns for a payload `A`."""
    # A payload-specific constructor has a non-generic call signature. This
    # avoids generic method witness selection through a nested native Tuple.
    # Existing families retain their pure implementation through the default.
    comptime _PureAction[A: Movable & Deinitable]: Unary & Defaultable = _FamilyPure[Self, A]
    comptime CombineCompatible[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable]: Bool = True
    """Admission for combination, including family-specific carrier and error origins."""
    comptime CollectCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Bool = True
    """Admission for collection into this family; collecting source traversals forward this predicate."""
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable]: Movable & Deinitable
    """The carrier `map2_lazy` returns."""
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable]: Movable & Deinitable
    """The error `map2_lazy` raises."""
    # Private policy admission is opt-in for existing custom dictionaries.
    comptime _LoopCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate]: Bool = True
    comptime _Looped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate]: Movable & Deinitable = Self.Pure[K.Acc]
    comptime _LoopError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate]: Movable & Deinitable = _CommonError[
        K.Error, Self.CombineError[Self.Pure[K.Acc], _FoldShape[K],
                                   _PullShape[Self.Mapped[F.Out, _Present[K.Item]], F.Error, Self.MapError[F.Out, _Present[K.Item]]]]]
    comptime Collected[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Movable & Deinitable = Self._Looped[V, F, _Append[Self.Element[F.Out]]]
    """The carrier `collect` returns: this family's carrier of a `List`."""
    comptime CollectError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Movable & Deinitable = Self._LoopError[V, F, _Append[Self.Element[F.Out]]]
    """The error `collect` raises."""
    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]:
        """Introduce a payload in the family's neutral context.

        Parameters:
            A: The payload type.

        Args:
            value: The payload, consumed.

        Returns:
            The carrier holding `value`.
        """
        ...
    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](
        var f: F, var left: V, var right: R
    ) raises Self.CombineError[V, F, R] -> Self.Combined[V, F, R]:
        """Combine the payloads of `left` and of the carrier `right` produces with `f`.

        `right` runs zero or one times per combination: a left carrier with no
        payload, such as an absent `Optional`, may skip it. Validation forces
        the right operand even after a stored error to accumulate both errors.

        Parameters:
            V: The left carrier's type.
            F: The combiner's type, taking the two payloads.
            R: The right operand's type: a thunk producing a carrier of this family.

        Args:
            f: The combiner, consumed.
            left: The left carrier, consumed.
            right: The thunk producing the right carrier, consumed.

        Returns:
            The carrier of the combined payloads.

        Raises:
            The combiner's or the thunk's error.
        """
        ...
    @staticmethod
    def collect[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var source: V
    ) raises Self.CollectError[V, F] -> Self.Collected[V, F]:
        """Call `f` on each element of `source` and gather the payloads into one carrier of a `List`.

        The family decides whether a stored failure stops source pulls. Ordinary
        Result and Optional stop; validation continues to accumulate errors.

        Parameters:
            V: The source's type: an iterator or an owned iterable.
            F: The callback's type, returning a carrier of this family; it must
                be repeatable.

        Args:
            f: The callback, consumed.
            source: The source, consumed.

        Returns:
            The carrier of the payloads, in source order.

        Raises:
            The callback's error, and any error the family's combination raises.
        """
        comptime K = _Append[Self.Element[F.Out]]
        comptime assert _ErrorCompatible[Self.CollectError[V, F], Self._LoopError[V, F, K]]
        return rebind_var[Self.Collected[V, F]](_loop_as[Self.CollectError[V, F], Self, V, F, K](f^, source^))
    @staticmethod
    def _loop[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate](var f: F, var source: V
    ) raises Self._LoopError[V, F, K] -> Self._Looped[V, F, K]:
        comptime X = K.Item
        comptime Acc = Self.Pure[K.Acc]
        comptime Shape = _PullShape[Self.Mapped[F.Out, _Present[X]], F.Error, Self.MapError[F.Out, _Present[X]]]
        comptime E = Self._LoopError[V, F, K]
        comptime assert RepeatableUnary[F], "traverse: the callback must be repeatable"
        comptime assert _Item[V] == F.Arg, "traverse: callback argument must be the source element"
        comptime assert Self.Element[F.Out] == X, "traverse: the accumulator must receive the callback's payload"
        comptime assert Self.Pure[Optional[X]] == Shape.Out, "traverse: target must represent a pulled element and exhaustion with one type"
        comptime assert Self._Looped[V, F, K] == Acc, "traverse: this target overrides _loop"
        comptime assert _ErrorCompatible[E, K.Error]
        var iterator = _iterator(source^)
        var start = _start_as[E, K]()
        var live = K.live(start)
        var result = _pure[Self](start^)
        while live:
            # The fold records whether a branch is still live. A skipped right
            # operand leaves `ended` set: once the accumulator has failed or
            # the source is exhausted, the source is never pulled again.
            live = False
            var ended = True
            var fold = _Fold[K, origin_of(live)](Pointer(to=live))
            var pull = _Pull[Self, V, F, X, origin_of(iterator), origin_of(f), origin_of(ended)](
                Pointer(to=iterator), Pointer(to=f), Pointer(to=ended))
            comptime Folding = type_of(fold)
            comptime Step = type_of(pull)
            comptime assert Self.Combined[Acc, Folding, Step] == Acc, "traverse: target accumulator type must not change between steps"
            comptime assert Self.CombineError[Acc, Folding, Step] == Self.CombineError[Acc, _FoldShape[K], Shape], "traverse: target combination error must depend only on the operand's result and error"
            comptime assert _ErrorCompatible[E, Self.CombineError[Acc, Folding, Step]]
            result = rebind_var[Acc](_map2_lazy_as[E, Self](fold^, result^, pull^))
            if ended:
                break
        return rebind_var[Self._Looped[V, F, K]](result^)


# Only Functor projections are needed for shape admission. Passing the stored
# error and membership evidence separately avoids recursive ApplicativeError
# conformance while a transformer's _Handles is itself being defined.
comptime _RecoveryShape[I: Functor, E: Movable & Deinitable, V: Movable & Deinitable,
                       H: UnaryContract & Movable & Deinitable, source: Bool, target: Bool]: Bool = (
    source and target and H.Arg == E and I.Element[V] == I.Element[H.Out]
)


trait ErrorRecovery(Applicative):
    """An Applicative that can recover its selected stored-error channel.

    Recovery consumes the selected error once and preserves the payload type.
    A family may leave terminal states outside this channel: async cancellation
    and failures marked canceled bypass recovery, retaining all their errors.
    This capability supplies no failure constructor and makes no raise/handle
    law claim. Native exceptions raised during construction remain separate.
    """
    comptime Failure: Movable & Deinitable
    """The selected stored error type, including its origins."""
    comptime Handled[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The carrier returned by handling the selected stored error of V."""
    comptime HandleError[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The exact native error raised while constructing the handled carrier."""

    # Fluent admission lives in signatures: body-level type equality alone can
    # erase distinctions between embedded origins on Mojo 1.1. Deferred carrier
    # types need not equal Pure; each instance validates its own native shape.
    comptime _ErrorCarrier[V: Movable & Deinitable]: Bool = True
    comptime _Handles[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable]: Bool = _RecoveryShape[Self,Self.Failure,V,H,Self._ErrorCarrier[V],Self._ErrorCarrier[H.Out]]

    @staticmethod
    def or_else[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V
    ) raises Self.HandleError[V, H] -> Self.Handled[V, H]:
        """Recover the selected stored error with another effect of this family.

        Parameters:
            V: The consumed source carrier type.
            H: A handler consuming Failure and returning this family's carrier
                of the original success type; repeatable for branching sources.

        Args:
            handler: The handler, consumed; skipped on success.
            source: The carrier, consumed with its native origins.

        Returns:
            Original successes or handler outputs in family order. A handler's
            failure passes onward without invoking that handler again.

        Raises:
            The exact native construction error; native raises are never recovered.
        """
        ...


trait ApplicativeError(ErrorRecovery):
    """An error-recovering Applicative with a lawful stored-failure constructor.

    Raising a selected stored failure and handling it obeys the ordinary
    ApplicativeError laws. Native exceptions remain separate from stored errors.
    """
    comptime Failed[A: Movable & Deinitable]: Movable & Deinitable
    """The carrier of a stored failure with success payload type A."""
    comptime FailError[A: Movable & Deinitable]: Movable & Deinitable
    """The native error raised while constructing that failed carrier."""
    @staticmethod
    def fail[A: Movable & Deinitable](var error: Self.Failure) raises Self.FailError[A] -> Self.Failed[A]:
        """Construct a stored failure without a success payload.

        Parameters:
            A: The absent success payload's type.

        Args:
            error: The stored error, consumed without copying.

        Returns:
            The family's failed carrier.

        Raises:
            The family's native construction error; the stored error is not raised.
        """
        ...



trait Monad(Applicative):
    """An `Applicative` whose callback chooses the next computation from the current payload: `flat_map`.

    Effectful reductions inherit the private `_fold` driver over pure, map
    and bind. Deferred families override `_Folded`, `_FoldError` and `_fold`
    to retain the source, initial accumulator and callbacks until execution.
    """
    comptime BindCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Bool = True
    """Additional admission for bind, including callback-result and native-error origins."""
    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The carrier `flat_map` returns: the callback's own carrier type."""
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The error `flat_map` raises."""
    # One dependent accumulation boundary. Eager families inherit the loop;
    # deferred families store its inputs and delegate when run.
    # Custom fold implementations retain their existing contract by default.
    comptime _FoldCompatible[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator]: Bool = True
    comptime _Folded[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator]: Movable & Deinitable = Self.Pure[K.Acc]
    comptime _FoldError[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator]: Movable & Deinitable = _BindLoop[Self, P, F, K].Error
    @staticmethod
    def _fold[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator](var prepare: P, var step: F, var initial: K.Acc, var source: V
    ) raises Self._FoldError[V, P, F, K] -> Self._Folded[V, P, F, K]:
        comptime assert Self._Folded[V, P, F, K] == Self.Pure[K.Acc]
        try:
            return rebind_var[Self._Folded[V, P, F, K]](_bind_loop[Self, V, P, F, K](prepare^, step^, initial^, source^))
        except error:
            comptime assert _ErrorCompatible[Self._FoldError[V, P, F, K], type_of(error)]
            _propagate_error[Self._FoldError[V, P, F, K]](error^)
    @staticmethod
    def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V
    ) raises Self.BindError[V, F] -> Self.Bound[V, F]:
        """Continue with the carrier `f` returns for the payload of `value`.

        Parameters:
            V: The carrier's type.
            F: The callback's type, returning a carrier of this family.

        Args:
            f: The callback, consumed.
            value: The carrier, consumed.

        Returns:
            The carrier the callback returned, or the original context when
            there is no payload.

        Raises:
            The callback's error.
        """
        ...


trait Traversable(Functor):
    """A source shape whose elements can be visited with an effectful callback, keeping the shape: `traverse`."""
    comptime TraverseCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Bool = Self.MapCompatible[V, F]
    """Source admission for traversal; may accept more than materialized carriers."""
    comptime TargetCompatible[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Bool = G.CollectCompatible[V, F]
    """Target operations used by this source traversal; collection by default."""
    comptime Traversed[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The carrier `traverse` returns: `G`'s carrier of this shape."""
    comptime TraverseError[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Movable & Deinitable
    """The error `traverse` raises."""
    @staticmethod
    def traverse[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var source: V
    ) raises Self.TraverseError[G, V, F] -> Self.Traversed[G, V, F]:
        """Call `f` on each element of `source`, in order, and gather the results into one `G` carrier of the same shape.

        Parameters:
            G: The applicative family the callback returns.
            V: The source's type, of this shape.
            F: The callback's type, returning a `G` carrier.

        Args:
            f: The callback, consumed.
            source: The source, consumed.

        Returns:
            `G`'s carrier of the results, in source shape and order.

        Raises:
            The callback's error, and any error `G` adds.
        """
        ...


trait _Lifting:
    """Embed a base carrier as a carrier of this family."""
    comptime Lifted[V: Movable & Deinitable]: Movable & Deinitable
    comptime LiftError[V: Movable & Deinitable]: Movable & Deinitable
    @staticmethod
    def lift[V: Movable & Deinitable](var value: V) raises Self.LiftError[V] -> Self.Lifted[V]:
        ...


trait Semigroup:
    """An associative, ordered combination of two values, without an identity."""
    comptime Value: Movable & Deinitable
    """The combined values' exact type, including origins."""
    comptime Error: Movable & Deinitable = Never
    """The native error of combination; Never by default."""
    @staticmethod
    def combine(var left: Self.Value, var right: Self.Value) raises Self.Error -> Self.Value:
        """Combine two values, `left` first.

        Args:
            left: The first value, consumed.
            right: The second value, consumed.

        Returns:
            The combination.

        Raises:
            `Error`; nothing when it is `Never`.
        """
        ...


trait Monoid(Semigroup):
    """A Semigroup with an identity element; Writer logs use one.

    The inherited Error covers both empty and combine.
    """
    @staticmethod
    def empty() raises Self.Error -> Self.Value:
        """The identity element: combining it with a value returns the value.

        Returns:
            The identity element.

        Raises:
            `Error`; nothing when it is `Never`.
        """
        ...

@fieldwise_init
struct _SemigroupBinary[S: Semigroup](Binary, Copyable, Defaultable):
    """Expose ordered Semigroup combination to the shared binary call boundary."""
    comptime First = Self.S.Value
    comptime Second = Self.S.Value
    comptime Out = Self.S.Value
    comptime Error = Self.S.Error
    def call(self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        return Self.S.combine(first^, second^)


# Owned iteration. An iterator continues from its current position; any other
# owned iterable starts a fresh iteration. Restarting an iterator would re-pull.
comptime _Iterator[V: Movable & Deinitable] = _Source[V]
comptime _Item[V: Movable & Deinitable] = downcast[_Iterator[V].Element, Movable & Deinitable]


def _iterator[V: Movable & Deinitable](var source: V) -> _Iterator[V]:
    comptime assert conforms_to(V, Iterator) or conforms_to(V, IterableOwned), "traverse: the source must be an iterator or an owned iterable"
    return _source(source^)


def _next_item[V: Movable & Deinitable](mut iterator: _Iterator[V]) -> Optional[_Item[V]]:
    """Pull the next source element through the canonical iterator advance."""
    return _next_optional[_Item[V]](iterator)


@fieldwise_init
struct _Present[B: Movable & Deinitable](Unary, Copyable, Defaultable):
    """Mark one produced element as present."""
    comptime Arg = Self.B
    comptime Out = Optional[Self.B]
    def call(self, var arg: Self.Arg) -> Self.Out:
        return Optional(arg^)


trait _LiveAccumulator:
    """The payload of a loop and whether a branch needs another input."""
    comptime Acc: Movable & Deinitable
    @staticmethod
    def live(ref acc: Self.Acc) -> Bool:
        ...


trait _Accumulate(_LiveAccumulator):
    """How a traversal loop folds produced payloads into its accumulator.

    `live` tells the loop whether pulling further elements can still change the
    accumulator. `combine` must return an accumulator that is no longer live
    unchanged.
    """
    comptime Item: Movable & Deinitable
    comptime Error: Movable & Deinitable = Never
    @staticmethod
    def start() raises Self.Error -> Self.Acc:
        ...
    @staticmethod
    def combine(var acc: Self.Acc, var item: Self.Item) raises Self.Error -> Self.Acc:
        ...


@fieldwise_init
struct _AccumulatePair[K: _Accumulate](Binary, Copyable, Defaultable):
    comptime First = Self.K.Acc
    comptime Second = Self.K.Item
    comptime Out = Self.K.Acc
    comptime Error = Self.K.Error
    def call(self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        return Self.K.combine(first^, second^)


struct _Append[B: Movable & Deinitable](_Accumulate):
    """Collect every payload in order."""
    comptime Acc = List[Self.B]
    comptime Item = Self.B
    comptime Error = Never
    @staticmethod
    def start() -> Self.Acc:
        return List[Self.B]()
    @staticmethod
    def live(ref acc: Self.Acc) -> Bool:
        return True
    @staticmethod
    def combine(var acc: Self.Acc, var item: Self.Item) -> Self.Acc:
        return _append[Self.B](acc^, item^, Tuple())


def _map_as[E: Movable & Deinitable, M: Functor, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var f: F, var value: V
) raises E -> M.Mapped[V, F] where _ErrorCompatible[E, M.MapError[V, F]]:
    try:
        return M.map(f^, value^)
    except error:
        _propagate_error[E](error^)


def _flat_map_as[E: Movable & Deinitable, M: Monad, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var f: F, var value: V
) raises E -> M.Bound[V, F] where _ErrorCompatible[E, M.BindError[V, F]]:
    try:
        return M.flat_map(f^, value^)
    except error:
        _propagate_error[E](error^)


def _map2_lazy_as[E: Movable & Deinitable, M: Applicative, V: Movable & Deinitable,
                  F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](
    var f: F, var left: V, var right: R
) raises E -> M.Combined[V, F, R] where _ErrorCompatible[E, M.CombineError[V, F, R]]:
    try:
        return M.map2_lazy(f^, left^, right^)
    except error:
        _propagate_error[E](error^)


def _traverse_as[S: Traversable, G: Applicative, V: Movable & Deinitable,
                 F: UnaryContract & Movable & Deinitable, Raised: Movable & Deinitable](
    var function: F, var source: V
) raises Raised -> S.Traversed[G, V, F]:
    # A generic native wrapper may provide its exact error as evidence. Keep
    # the family's existing symbolic spelling and validate identity here.
    try:
        return S.traverse[G](function^, source^)
    except error:
        comptime assert _ErrorCompatible[Raised, type_of(error)]
        _propagate_error[Raised](error^)


def _loop_as[E: Movable & Deinitable, M: Applicative, V: Movable & Deinitable,
             F: UnaryContract & Movable & Deinitable, K: _Accumulate](var function: F, var source: V
) raises E -> M._Looped[V, F, K]:
    # Keep the family's symbolic error and validate the native error it raises.
    try:
        return M._loop[V, F, K](function^, source^)
    except error:
        comptime assert _ErrorCompatible[E, type_of(error)]
        _propagate_error[E](error^)


def _fold_as[E: Movable & Deinitable, M: Monad, V: Movable & Deinitable,
             P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable,
             K: _LiveAccumulator](var prepare: P, var step: F, var initial: K.Acc, var source: V
) raises E -> M._Folded[V, P, F, K]:
    # Keep the family's symbolic error and validate the native error it raises.
    try:
        return M._fold[V, P, F, K](prepare^, step^, initial^, source^)
    except error:
        comptime assert _ErrorCompatible[E, type_of(error)]
        _propagate_error[E](error^)


def _start_as[E: Movable & Deinitable, K: _Accumulate]() raises E -> K.Acc where _ErrorCompatible[E, K.Error]:
    try:
        return K.start()
    except error:
        _propagate_error[E](error^)


def _combine_as[E: Movable & Deinitable, K: _Accumulate](var acc: K.Acc, var item: K.Item
) raises E -> K.Acc where _ErrorCompatible[E, K.Error]:
    try:
        return K.combine(acc^, item^)
    except error:
        _propagate_error[E](error^)


# Admission for the existing linear pull/call/accumulate owner. Unlike List's
# Cartesian loop, linear loops do not copy payloads, accumulators or captures.
# Collection checks its carrier separately, so generic equality evidence need
# not cross an accumulator item projection. Custom loops also check that item.
comptime _LinearProducerCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable,
                                   Failure: Movable & Deinitable] = (
    (_Item[V] == F.Arg) & _CommonErrorCompatible[F.Error, Failure]
) if (conforms_to(V, Iterator) or conforms_to(V, IterableOwned)) and RepeatableUnary[F] else False


comptime _LinearLoopCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable,
                               Item: Movable & Deinitable, Failure: Movable & Deinitable] = (
    _LinearProducerCompatible[V, F, Failure] & (F.Out == Item)
)


def _map_accumulate[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate,
                    E: Movable & Deinitable = _CommonError[F.Error, K.Error]](
    var f: F, var source: V, var acc: K.Acc
) raises E -> K.Acc:
    """The Identity traversal loop, with a caller-supplied native accumulator.

    Collection mapping also uses this loop: supplying the initial accumulator
    preserves runtime container settings without a second traversal mechanism.
    """
    comptime assert RepeatableUnary[F], "traverse: the callback must be repeatable"
    comptime assert _Item[V] == F.Arg, "traverse: callback argument must be the source element"
    comptime assert F.Out == K.Item, "traverse: the accumulator must receive the callback's payload"
    comptime assert _ErrorCompatible[E, F.Error] and _ErrorCompatible[E, K.Error]
    var iterator = _iterator(source^)
    while K.live(acc):
        var item = _next_item[V](iterator)
        if not item:
            break
        var produced = _unary_repeated_as[E](f, rebind_var[F.Arg](item.unsafe_take()))
        acc = _combine_as[E, K](acc^, rebind_var[K.Item](produced^))
    return acc^


@fieldwise_init
struct _Fold[K: _Accumulate, o: MutOrigin](Binary):
    """Combine a present element and record whether the result is live;
    exhaustion leaves the accumulator unchanged."""
    var live: Pointer[Bool, Self.o]
    comptime First = Self.K.Acc
    comptime Second = Optional[Self.K.Item]
    comptime Out = Self.K.Acc
    comptime Error = Self.K.Error
    def call(self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        if not second:
            return first^
        # This branch proves presence; avoid a second checked take.
        var acc = Self.K.combine(first^, second.unsafe_take())
        if Self.K.live(acc):
            self.live[] = True
        return acc^


@fieldwise_init
struct _FoldShape[K: _Accumulate](BinaryContract):
    # The types and error of `_Fold`, without its scoped pointer.
    comptime First = Self.K.Acc
    comptime Second = Optional[Self.K.Item]
    comptime Out = Self.K.Acc
    comptime Error = Self.K.Error


struct _Lazy[G: ThunkContract & Movable & Deinitable](
    Movable, Copyable where conforms_to(G, Copyable) and conforms_to(G.Out, Copyable)
):
    """A lazy right operand: produced at most once, then retained so that
    later branches receive copies."""
    var thunk: Optional[Self.G]
    var produced: Optional[Self.G.Out]
    def __init__(out self, var thunk: Self.G):
        self.thunk = Optional(thunk^)
        self.produced = Optional[Self.G.Out]()
    def take[X: Movable & Deinitable = Self.G.Error](deinit self) raises X -> Self.G.Out where _ErrorCompatible[X, Self.G.Error]:
        """Consume the operand: the retained value, or produce it now."""
        var produced = self.produced^
        if produced:
            return produced.unsafe_take()
        var thunk = self.thunk^
        return _thunk_once_as[X](thunk.unsafe_take())
    def copy_value[X: Movable & Deinitable = Self.G.Error](mut self) raises X -> Self.G.Out where _ErrorCompatible[X, Self.G.Error]:
        """Produce the operand on first use and return a copy of it."""
        comptime assert conforms_to(Self.G.Out, Copyable), "map2: repeated branches copy the right operand"
        if not self.produced:
            self.produced = Optional(_thunk_once_as[X](self.thunk.unsafe_take()))
        comptime C = downcast[Self.G.Out, Copyable & Deinitable]
        return rebind_var[Self.G.Out](rebind[C](self.produced.value()).copy())


@fieldwise_init
struct _PullShape[O: Movable & Deinitable, FE: Movable & Deinitable, ME: Movable & Deinitable](ThunkContract):
    # Result and error of one pull, without the scoped pointers of `_Pull`.
    comptime Out = Self.O
    comptime Error = _CommonError[Self.FE, Self.ME]


@fieldwise_init
struct _Pull[G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, B: Movable & Deinitable,
             io: MutOrigin, fo: MutOrigin, eo: MutOrigin](OnceThunk):
    """Pull and map the next source element, or produce exhaustion."""
    var source: Pointer[_Iterator[Self.V], origin=Self.io]
    var function: Pointer[Self.F, origin=Self.fo]
    var ended: Pointer[Bool, origin=Self.eo]
    comptime Shape = _PullShape[Self.G.Mapped[Self.F.Out, _Present[Self.B]], Self.F.Error, Self.G.MapError[Self.F.Out, _Present[Self.B]]]
    comptime Out = Self.Shape.Out
    comptime Error = Self.Shape.Error
    def call_once(deinit self) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.F], "traverse: the callback must be repeatable"
        var item = _next_item[Self.V](self.source[])
        if not item:
            self.ended[] = True
            return rebind_var[Self.Out](_pure[Self.G](Optional[Self.B]()))
        self.ended[] = False
        comptime ME = Self.G.MapError[Self.F.Out, _Present[Self.B]]
        comptime assert _ErrorCompatible[Self.Error, Self.F.Error] and _ErrorCompatible[Self.Error, ME]
        # The exhaustion branch above returned; the item is present here.
        var produced = _unary_repeated_as[Self.Error](self.function[], rebind_var[Self.F.Arg](item.unsafe_take()))
        return _map_as[Self.Error, Self.G](_Present[Self.B](), produced^)


# Monad default dependent accumulation.
# These shapes project types only. The callable protocol owner supplies their
# unary signature; _Probe and _Step below remain the execution owners.
comptime _ProbeShape[K: _LiveAccumulator] = _ErrorProbe[K.Acc, K.Acc, Never]


@fieldwise_init
struct _Probe[K: _LiveAccumulator, o: MutOrigin](Unary):
    var live: Pointer[Bool, Self.o]
    comptime Arg = _ProbeShape[Self.K].Arg
    comptime Out = _ProbeShape[Self.K].Out
    def call(self, var arg: Self.Arg) -> Self.Out:
        if Self.K.live(arg):
            self.live[] = True
        return arg^


comptime _StepShape[M: Monad, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator] = _ErrorProbe[K.Acc, M._Joined[M.Pure[K.Acc], F.Out], F.Error]


@fieldwise_init
struct _Step[M: Monad, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator, o: MutOrigin](
    OnceUnary, MutableUnary where conforms_to(F.Second, Copyable)
):
    var function: Pointer[Self.F, Self.o]
    var item: Self.F.Second
    comptime Arg = _StepShape[Self.M, Self.F, Self.K].Arg
    comptime Out = _StepShape[Self.M, Self.F, Self.K].Out
    comptime Error = _StepShape[Self.M, Self.F, Self.K].Error

    @staticmethod
    def _apply(mut function: Self.F, var arg: Self.Arg, var item: Self.F.Second) raises Self.Error -> Self.Out:
        comptime assert Self.F.First == Self.Arg
        comptime assert RepeatableBinary[Self.F], "fold_effect: step must be repeatable"
        if not Self.K.live(arg):
            return Self.M._join_left[Self.M.Pure[Self.K.Acc], Self.F.Out](_pure[Self.M](arg^))
        var produced = _binary_repeated_as[Self.Error](function, rebind_var[Self.F.First](arg^), item^)
        return Self.M._join_right[Self.M.Pure[Self.K.Acc], Self.F.Out](produced^)

    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        return Self._apply(self.function[], arg^, self.item^)

    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime C = downcast[Self.F.Second, Copyable & Deinitable]
        var item = rebind_var[Self.F.Second](rebind[C](self.item).copy())
        return Self._apply(self.function[], arg^, item^)


# Admission for the four native eager families using the default fold driver.
# Describe their exact output and branching policy without asking an incomplete
# family to prove its Monad conformance while defining its own predicate.
comptime _NativeFoldCompatible[V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable,
                              F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator,
                              Carrier: Movable & Deinitable, branching: Bool] = (
    RepeatableUnary[P] & RepeatableBinary[F] &
    (P.Arg == _Item[V]) & (P.Out == F.Second) & (F.First == K.Acc) &
    (F.Out == Carrier) & _CommonErrorCompatible[P.Error, F.Error] &
    (not branching or conforms_to(F.Second, Copyable))
) if conforms_to(V, Iterator) or conforms_to(V, IterableOwned) else False


struct _AllLive[A: Movable & Deinitable](_LiveAccumulator):
    comptime Acc = Self.A
    @staticmethod
    def live(ref acc: Self.Acc) -> Bool: return True



struct _BindLoop[M: Monad, P: UnaryContract & Movable & Deinitable, F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator]:
    comptime Acc = Self.M.Pure[Self.K.Acc]
    comptime Error = _CommonError[Self.P.Error, _CommonError[
        Self.M.MapError[Self.Acc, _ProbeShape[Self.K]],
        Self.M.BindError[Self.Acc, _StepShape[Self.M, Self.F, Self.K]]]]


def _bind_loop[M: Monad, V: Movable & Deinitable, P: UnaryContract & Movable & Deinitable,
               F: BinaryContract & Movable & Deinitable, K: _LiveAccumulator](
    var prepare: P, var step: F, var initial: K.Acc, var source: V
) raises _BindLoop[M, P, F, K].Error -> M.Pure[K.Acc]:
    comptime E = _BindLoop[M, P, F, K].Error
    comptime Acc = M.Pure[K.Acc]
    comptime assert RepeatableUnary[P] and RepeatableBinary[F], "fold_effect: callbacks must be repeatable"
    comptime assert P.Arg == _Item[V] and P.Out == F.Second and F.First == K.Acc, "fold_effect: incompatible step arguments"
    comptime assert M.Element[F.Out] == K.Acc, "fold_effect: step must preserve the accumulator type"
    comptime assert _ErrorCompatible[E, P.Error] and _ErrorCompatible[E, F.Error], "fold_effect: incompatible native errors"
    var iterator = _iterator(source^)
    var result = _pure[M](initial^)
    while True:
        var live = False
        comptime Probe = _Probe[K, origin_of(live)]
        comptime assert M.Mapped[Acc, Probe] == Acc, "fold_effect: eager carrier must keep one type across steps"
        comptime assert M.MapError[Acc, Probe] == M.MapError[Acc, _ProbeShape[K]]
        comptime assert _ErrorCompatible[E, M.MapError[Acc, Probe]]
        result = rebind_var[Acc](_map_as[E, M](Probe(Pointer(to=live)), result^))
        if not live:
            return result^
        var item = _next_item[V](iterator)
        if not item:
            return result^
        var prepared = _unary_repeated_as[E](prepare, rebind_var[P.Arg](item.unsafe_take()))
        comptime Step = _Step[M, F, K, origin_of(step)]
        comptime assert M.Bound[Acc, Step] == Acc, "fold_effect: eager carrier must keep one type across steps"
        comptime assert M.BindError[Acc, Step] == M.BindError[Acc, _StepShape[M, F, K]]
        comptime assert _ErrorCompatible[E, M.BindError[Acc, Step]]
        result = rebind_var[Acc](_flat_map_as[E, M](Step(Pointer(to=step), rebind_var[F.Second](prepared^)), result^))
