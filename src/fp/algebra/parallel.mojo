"""Concurrent traversal over a family's `Parallel` counterpart: Cats' `parTraverse`, `parSequence` and `parTraverseN`.

`par_traverse[I]` is `traverse` with `I.Par`, and `par_sequence[I]` is
`sequence` with it: the source's `Traversable` instance and the target's
private `_loop` do all the work, through the same `_traverse_as` entry that
`traverse` uses. For `Async[E]`, `I.Par` is `AsyncPar[E]`, so every element's
IO runs as a child fiber of the running fiber. A family without `Parallel`,
such as `SyncIO[E]`, is rejected at the constraint.

The bounded forms `par_traverse_n`, `par_sequence_n` and
`par_traverse_void_n` run at most `limit` elements at once, through the same
loop with a live limit (`_LimitedLoop._loop_limited`), so they keep O(limit)
live children for any source length. Their sources are those the loop takes,
owned iterables and iterators, and their result is the target's carrier of a
`List` (of `None` for `par_traverse_void_n`). A `limit` below one aborts at the
call, before any IO exists. `par_traverse_void` without a bound lives in
`fp.iteration`, beside `traverse_void`.
"""
from std.builtin.rebind import downcast, rebind_var
from std.os import abort
from fp.callables._views import _UnaryViewable
from fp.callables.protocols import UnaryContract, _ErrorProbe
from fp.callables.native import NativeUnary, _NativeUnaryRef, _NativeOwnedArg
from fp.callables._identity import Identity
from fp.iteration._advance import _Source
from fp._internal.errors import _ErrorCompatible, _propagate_error
from .protocols import Functor, Applicative, Traversable, Parallel, _LimitedLoop, _Append, _Accumulate, _traverse_as
from ._contracts import TraverseContract
from ._traversal import _Discard
from .collections import _SourceFamily, _UnrecognizedCarrier
from .instances import _NativeFamily, _ViewFamily
from .operations import _EntryError, _InferError


struct _NotParallel(Parallel):
    """The inferred family of a carrier without `Parallel`: its `Par` admits nothing, so the call is rejected."""
    comptime Par = _UnrecognizedCarrier


# The fluent Iter forms select the callback result's family when it has
# `Parallel`; a family without it projects to a `Par` that admits nothing.
comptime _InferredParallel[V: Movable & Deinitable]: Parallel = downcast[
    _NativeFamily[V] if conforms_to(_NativeFamily[V], Parallel) else _NotParallel, Parallel]
comptime _SourceElement[V: Movable & Deinitable] = downcast[_Source[V].Element, Movable & Deinitable]

# The free entry points take any family and require `conforms_to(I, Parallel)`
# first in their where clauses. A `Parallel` bound on the parameter would reject
# OptionalT and ResultT as written: their public aliases are typed by the
# Identity branch too, which has no Parallel, so only `conforms_to` sees the
# conditional conformance. A family without it projects to a target that
# admits nothing, keeping every signature well-formed while the constraint
# reports the rejection.
comptime _ParOf[I: Functor]: Applicative = downcast[I, Parallel].Par if conforms_to(I, Parallel) else _UnrecognizedCarrier


def par_traverse[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, //, I: Functor = _NativeFamily[F.Out], S: Traversable = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Traversable) else _UnrecognizedCarrier, Traversable]](
    var source: V, var f: F
) raises TraverseContract[S, _ParOf[I], V, F].Error -> TraverseContract[S, _ParOf[I], V, F].Out where conforms_to(I, Parallel) and TraverseContract[S, _ParOf[I], V, F].InputCompatible and TraverseContract[S, _ParOf[I], V, F].TargetCompatible:
    """Call an effectful `f` on each element of `source` and run the effects concurrently: `traverse` with `I.Par`.

    For `Async[E]`, each element's IO runs as a child fiber of the running
    fiber. Callbacks run on the running fiber in source order when the IO
    runs, and results keep source order. The first element that ends
    unsuccessfully stops the others; every started child finishes before the
    IO completes, and its failure carries every error observed by then, in
    element order. Elements not yet pulled are never started. Other overloads
    take a native function directly.

    Parameters:
        V: The source's type.
        F: The callback's type: a repeatable library `Unary` value returning an `I` carrier.
        I: A family with `Parallel`, such as `Async[E]` or `OptionalT[Async[E]]`; defaults to the family of the callback's result.
        S: The source's instance; defaults to the source's family.

    Args:
        source: The source, consumed.
        f: The callback, consumed.

    Returns:
        `I.Par`'s carrier of the results in source shape.

    Raises:
        The callback's error, and any error `I.Par` adds; nothing for `Async[E]`, whose errors are the IO's failure.
    """
    return S.traverse[_ParOf[I]](f^, source^)


def par_sequence[V: Movable & Deinitable, //, I: Functor = _NativeFamily[downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Traversable) else _UnrecognizedCarrier, Traversable].Element[V]], S: Traversable = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Traversable) else _UnrecognizedCarrier, Traversable]](var source: V
) raises S.TraverseError[_ParOf[I], V, Identity[S.Element[V]]] -> S.Traversed[_ParOf[I], V, Identity[S.Element[V]]] where conforms_to(I, Parallel) and S.TargetCompatible[_ParOf[I], V, Identity[S.Element[V]]]:
    """Run a source of `I` carriers concurrently and gather their payloads: `sequence` with `I.Par`.

    Parameters:
        V: The source's type, such as `List[IO[A, E]]`.
        I: A family with `Parallel`; defaults to the family of the source's elements.
        S: The source's instance; defaults to the source's family.

    Args:
        source: The source, consumed.

    Returns:
        `I.Par`'s carrier of the payloads in source shape, with `par_traverse`'s
        failure and cancellation contract.

    Raises:
        Any error `I.Par` adds.
    """
    return S.traverse[_ParOf[I]](Identity[S.Element[V]](), source^)


def _check_limit(limit: Int, name: StaticString):
    """Abort at the call for a limit below one, before any program exists."""
    if limit < 1:
        abort(String(name, ": limit must be at least 1"))


def _limited_as[Raised: Movable & Deinitable, P: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate](
    limit: Int, var f: F, var source: V
) raises Raised -> P._Looped[V, F, K]:
    """The bounded entry into the target's one loop; signatures admit the family and the callback."""
    comptime assert conforms_to(P, _LimitedLoop), "bounded traversal: the family's Par has no limited loop"
    comptime L = downcast[P, _LimitedLoop]
    comptime assert L._Looped[V, F, K] == P._Looped[V, F, K]
    comptime assert _ErrorCompatible[Raised, L._LoopError[V, F, K]]
    try:
        return rebind_var[P._Looped[V, F, K]](L._loop_limited[V, F, K](limit, f^, source^))
    except error:
        _propagate_error[Raised](error^)


comptime _Collect[I: Functor, F: UnaryContract & Movable & Deinitable] = _Append[_ParOf[I].Element[F.Out]]
comptime _Void[I: Functor, F: UnaryContract & Movable & Deinitable] = _Discard[_ParOf[I].Element[F.Out]]


def par_traverse_n[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, //, I: Functor = _NativeFamily[F.Out]](
    limit: Int, var source: V, var f: F
) raises _ParOf[I]._LoopError[V, F, _Collect[I, F]] -> _ParOf[I]._Looped[V, F, _Collect[I, F]] where conforms_to(I, Parallel) and conforms_to(_ParOf[I], _LimitedLoop) and _Source[V].Element == F.Arg and _ParOf[I].CollectCompatible[V, F] and _ParOf[I]._LoopCompatible[V, F, _Collect[I, F]]:
    """Run at most `limit` elements' effects at once and gather the results in a `List`: Cats Effect's `parTraverseN`.

    A finished element frees its place for the next one even while an earlier
    element still runs, and its value waits in an index-addressed slot until
    every earlier element has finished, so a slow early element holds the later
    values that finished after it. Live children stay at most `limit`.
    `limit = 1` runs as `traverse` does, in outcome and in effect order. The
    failure and cancellation contract is `par_traverse`'s.

    Parameters:
        V: The source's type: an owned iterable or an iterator.
        F: The callback's type: a repeatable library `Unary` value returning an `I` carrier.
        I: A family with `Parallel`, such as `Async[E]` or `OptionalT[Async[E]]`; defaults to the family of the callback's result.

    Args:
        limit: The most elements running at once; below one aborts at the call.
        source: The source, consumed; elements are pulled only as places free.
        f: The callback, consumed.

    Returns:
        `I.Par`'s carrier of the results, in source order.

    Raises:
        Any error `I.Par`'s loop adds; nothing for `Async[E]`.
    """
    _check_limit(limit, "par_traverse_n")
    return _limited_as[_ParOf[I]._LoopError[V, F, _Collect[I, F]], _ParOf[I], V, F, _Collect[I, F]](limit, f^, source^)


def par_sequence_n[V: Movable & Deinitable, //, I: Functor = _NativeFamily[_SourceElement[V]]](
    limit: Int, var source: V
) raises _ParOf[I]._LoopError[V, Identity[_SourceElement[V]], _Collect[I, Identity[_SourceElement[V]]]] -> _ParOf[I]._Looped[V, Identity[_SourceElement[V]], _Collect[I, Identity[_SourceElement[V]]]] where conforms_to(I, Parallel) and conforms_to(_ParOf[I], _LimitedLoop) and _ParOf[I].CollectCompatible[V, Identity[_SourceElement[V]]] and _ParOf[I]._LoopCompatible[V, Identity[_SourceElement[V]], _Collect[I, Identity[_SourceElement[V]]]]:
    """Run at most `limit` of a source's `I` carriers at once and gather their payloads: Cats Effect's `parSequenceN`.

    Parameters:
        V: The source's type, such as `List[IO[A, E]]`: an owned iterable or an iterator.
        I: A family with `Parallel`; defaults to the family of the source's elements.

    Args:
        limit: The most carriers running at once; below one aborts at the call.
        source: The source, consumed.

    Returns:
        `I.Par`'s carrier of the payloads, in source order, with `par_traverse_n`'s contract.

    Raises:
        Any error `I.Par`'s loop adds; nothing for `Async[E]`.
    """
    _check_limit(limit, "par_sequence_n")
    comptime F = Identity[_SourceElement[V]]
    return _limited_as[_ParOf[I]._LoopError[V, F, _Collect[I, F]], _ParOf[I], V, F, _Collect[I, F]](limit, F(), source^)


def par_traverse_void_n[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, //, I: Functor = _NativeFamily[F.Out]](
    limit: Int, var source: V, var f: F
) raises _ParOf[I]._LoopError[V, F, _Void[I, F]] -> _ParOf[I]._Looped[V, F, _Void[I, F]] where conforms_to(I, Parallel) and conforms_to(_ParOf[I], _LimitedLoop) and _Source[V].Element == F.Arg and _ParOf[I].CollectCompatible[V, F] and _ParOf[I]._LoopCompatible[V, F, _Void[I, F]]:
    """Run at most `limit` elements' effects at once, keeping no results: Cats Effect's `parTraverseN_`.

    The accumulation rule discards each value as it finishes, so nothing waits
    for a slow earlier element. The contract is otherwise `par_traverse_n`'s.

    Parameters:
        V: The source's type: an owned iterable or an iterator.
        F: The callback's type: a repeatable library `Unary` value returning an `I` carrier.
        I: A family with `Parallel`, such as `Async[E]` or `OptionalT[Async[E]]`; defaults to the family of the callback's result.

    Args:
        limit: The most elements running at once; below one aborts at the call.
        source: The source, consumed.
        f: The callback, consumed.

    Returns:
        `I.Par`'s carrier of `None`.

    Raises:
        Any error `I.Par`'s loop adds; nothing for `Async[E]`.
    """
    _check_limit(limit, "par_traverse_void_n")
    return _limited_as[_ParOf[I]._LoopError[V, F, _Void[I, F]], _ParOf[I], V, F, _Void[I, F]](limit, f^, source^)


# Native functions and closures, generated from the callback catalog beside
# traverse's: each body is the call the library-callable form makes.
# --- native parallel admission (generated) ---
def par_traverse[V: Movable & Deinitable, F: _UnaryViewable, o: ImmOrigin, //, I: Functor = _ViewFamily[F, o], S: Traversable = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Traversable) else _UnrecognizedCarrier, Traversable]](var source: V, ref[o] function: F) raises S.TraverseError[_ParOf[I], V, F._View[o]] -> S.Traversed[_ParOf[I], V, F._View[o]] where conforms_to(I, Parallel) and S.TargetCompatible[_ParOf[I], V, F._View[o]]:
    """Admit a view callback; execution stays with the family."""
    comptime Raised = S.TraverseError[_ParOf[I], V, F._View[o]]
    comptime assert S.TraverseError[_ParOf[I], V, F._View[o]] == S.TraverseError[_ParOf[I], V, F._View[o]]
    comptime assert _ErrorCompatible[Raised, S.TraverseError[_ParOf[I], V, F._View[o]]]
    return _traverse_as[S, _ParOf[I], V, F._View[o], Raised](function._unary_view(), source^)


@always_inline
def par_traverse[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, I: Functor = _NativeFamily[R], S: Traversable = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Traversable) else _UnrecognizedCarrier, Traversable], F: def(var A) -> R = def(var A) -> R](var source: V, ref[o] function: F) raises S.TraverseError[_ParOf[I], V, _ErrorProbe[A, R, Never]] -> S.Traversed[_ParOf[I], V, _NativeUnaryRef[A, R, Never, F, False, o]] where S.Element[V] == A and conforms_to(I, Parallel) and S.TargetCompatible[_ParOf[I], V, _NativeUnaryRef[A, R, Never, F, False, o]]:
    """Admit a closure callback; execution stays with the family."""
    comptime Raised = S.TraverseError[_ParOf[I], V, _ErrorProbe[A, R, Never]]
    comptime assert S.TraverseError[_ParOf[I], V, _NativeUnaryRef[A, R, Never, F, False, o]] == S.TraverseError[_ParOf[I], V, _ErrorProbe[A, R, Never]]
    comptime assert _ErrorCompatible[Raised, S.TraverseError[_ParOf[I], V, _NativeUnaryRef[A, R, Never, F, False, o]]]
    return _traverse_as[S, _ParOf[I], V, _NativeUnaryRef[A, R, Never, F, False, o], Raised](_NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), source^)


@always_inline
def par_traverse[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, I: Functor = _NativeFamily[R], S: Traversable = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Traversable) else _UnrecognizedCarrier, Traversable], E: Movable & Deinitable = Never, F: def(var A) raises E -> R = def(var A) raises E -> R, X: AnyType = _InferError](var source: V, ref[o] function: F) raises _EntryError[X, S.TraverseError[_ParOf[I], V, _ErrorProbe[A, R, E]]] -> S.Traversed[_ParOf[I], V, _NativeUnaryRef[A, R, E, F, True, o]] where S.Element[V] == A and conforms_to(I, Parallel) and S.TargetCompatible[_ParOf[I], V, _NativeUnaryRef[A, R, E, F, True, o]] and (X == _InferError or X == E):
    """Admit a closure callback that raises; execution stays with the family."""
    comptime Raised = _EntryError[X, S.TraverseError[_ParOf[I], V, _ErrorProbe[A, R, E]]]
    comptime assert S.TraverseError[_ParOf[I], V, _NativeUnaryRef[A, R, E, F, True, o]] == S.TraverseError[_ParOf[I], V, _ErrorProbe[A, R, E]]
    comptime assert _ErrorCompatible[Raised, S.TraverseError[_ParOf[I], V, _NativeUnaryRef[A, R, E, F, True, o]]]
    return _traverse_as[S, _ParOf[I], V, _NativeUnaryRef[A, R, E, F, True, o], Raised](_NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), source^)


def par_traverse[V: Movable & Deinitable, R: Movable & Deinitable, //, I: Functor = _NativeFamily[R], S: Traversable = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Traversable) else _UnrecognizedCarrier, Traversable]](var source: V, function: def(var _NativeOwnedArg[S.Element[V]]) thin -> R) raises S.TraverseError[_ParOf[I], V, _ErrorProbe[NoneType, R, Never]] -> S.Traversed[_ParOf[I], V, NativeUnary[S.Element[V], R, Never, type_of(function), False]] where not conforms_to(R, RegisterPassable) and conforms_to(I, Parallel) and S.TargetCompatible[_ParOf[I], V, NativeUnary[S.Element[V], R, Never, type_of(function), False]]:
    """Admit a thin callback; execution stays with the family."""
    comptime Raised = S.TraverseError[_ParOf[I], V, _ErrorProbe[NoneType, R, Never]]
    comptime assert S.TraverseError[_ParOf[I], V, NativeUnary[S.Element[V], R, Never, type_of(function), False]] == S.TraverseError[_ParOf[I], V, _ErrorProbe[NoneType, R, Never]]
    comptime assert _ErrorCompatible[Raised, S.TraverseError[_ParOf[I], V, NativeUnary[S.Element[V], R, Never, type_of(function), False]]]
    return _traverse_as[S, _ParOf[I], V, NativeUnary[S.Element[V], R, Never, type_of(function), False], Raised](NativeUnary[S.Element[V], R, Never, type_of(function), False](function), source^)


def par_traverse[V: Movable & Deinitable, R: RegisterPassable & Deinitable, //, I: Functor = _NativeFamily[R], S: Traversable = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Traversable) else _UnrecognizedCarrier, Traversable]](var source: V, function: def(var _NativeOwnedArg[S.Element[V]]) thin -> R) raises S.TraverseError[_ParOf[I], V, _ErrorProbe[NoneType, R, Never]] -> S.Traversed[_ParOf[I], V, NativeUnary[S.Element[V], R, Never, type_of(function), False]] where conforms_to(I, Parallel) and S.TargetCompatible[_ParOf[I], V, NativeUnary[S.Element[V], R, Never, type_of(function), False]]:
    """Admit a thin callback; execution stays with the family."""
    comptime Raised = S.TraverseError[_ParOf[I], V, _ErrorProbe[NoneType, R, Never]]
    comptime assert S.TraverseError[_ParOf[I], V, NativeUnary[S.Element[V], R, Never, type_of(function), False]] == S.TraverseError[_ParOf[I], V, _ErrorProbe[NoneType, R, Never]]
    comptime assert _ErrorCompatible[Raised, S.TraverseError[_ParOf[I], V, NativeUnary[S.Element[V], R, Never, type_of(function), False]]]
    return _traverse_as[S, _ParOf[I], V, NativeUnary[S.Element[V], R, Never, type_of(function), False], Raised](NativeUnary[S.Element[V], R, Never, type_of(function), False](function), source^)


def par_traverse[V: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, I: Functor = _NativeFamily[R], S: Traversable = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Traversable) else _UnrecognizedCarrier, Traversable]](var source: V, function: def(var _NativeOwnedArg[S.Element[V]]) raises E thin -> R) raises S.TraverseError[_ParOf[I], V, _ErrorProbe[NoneType, R, E]] -> S.Traversed[_ParOf[I], V, NativeUnary[S.Element[V], R, E, type_of(function), True]] where conforms_to(I, Parallel) and S.TargetCompatible[_ParOf[I], V, NativeUnary[S.Element[V], R, E, type_of(function), True]]:
    """Admit a thin callback that raises; execution stays with the family."""
    comptime Raised = S.TraverseError[_ParOf[I], V, _ErrorProbe[NoneType, R, E]]
    comptime assert S.TraverseError[_ParOf[I], V, NativeUnary[S.Element[V], R, E, type_of(function), True]] == S.TraverseError[_ParOf[I], V, _ErrorProbe[NoneType, R, E]]
    comptime assert _ErrorCompatible[Raised, S.TraverseError[_ParOf[I], V, NativeUnary[S.Element[V], R, E, type_of(function), True]]]
    return _traverse_as[S, _ParOf[I], V, NativeUnary[S.Element[V], R, E, type_of(function), True], Raised](NativeUnary[S.Element[V], R, E, type_of(function), True](function), source^)


def par_traverse_n[V: Movable & Deinitable, F: _UnaryViewable, o: ImmOrigin, //, I: Functor = _ViewFamily[F, o]](limit: Int, var source: V, ref[o] function: F) raises _ParOf[I]._LoopError[V, F._View[o], _Collect[I, F._View[o]]] -> _ParOf[I]._Looped[V, F._View[o], _Collect[I, F._View[o]]] where conforms_to(I, Parallel) and _Source[V].Element == F._View[o].Arg and conforms_to(_ParOf[I], _LimitedLoop) and _ParOf[I].CollectCompatible[V, F._View[o]] and _ParOf[I]._LoopCompatible[V, F._View[o], _Collect[I, F._View[o]]]:
    """Admit a view callback; the family's limited loop executes."""
    _check_limit(limit, "par_traverse_n")
    comptime assert _ParOf[I]._LoopError[V, F._View[o], _Collect[I, F._View[o]]] == _ParOf[I]._LoopError[V, F._View[o], _Collect[I, F._View[o]]]
    return _limited_as[_ParOf[I]._LoopError[V, F._View[o], _Collect[I, F._View[o]]], _ParOf[I], V, F._View[o], _Collect[I, F._View[o]]](limit, function._unary_view(), source^)


@always_inline
def par_traverse_n[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, I: Functor = _NativeFamily[R], F: def(var A) -> R = def(var A) -> R](limit: Int, var source: V, ref[o] function: F) raises _ParOf[I]._LoopError[V, _ErrorProbe[A, R, Never], _Collect[I, _ErrorProbe[A, R, Never]]] -> _ParOf[I]._Looped[V, _NativeUnaryRef[A, R, Never, F, False, o], _Collect[I, _NativeUnaryRef[A, R, Never, F, False, o]]] where conforms_to(I, Parallel) and downcast[_Source[V].Element, Movable & Deinitable] == A and conforms_to(_ParOf[I], _LimitedLoop) and _ParOf[I].CollectCompatible[V, _NativeUnaryRef[A, R, Never, F, False, o]] and _ParOf[I]._LoopCompatible[V, _NativeUnaryRef[A, R, Never, F, False, o], _Collect[I, _NativeUnaryRef[A, R, Never, F, False, o]]]:
    """Admit a closure callback; the family's limited loop executes."""
    _check_limit(limit, "par_traverse_n")
    comptime assert _ParOf[I]._LoopError[V, _NativeUnaryRef[A, R, Never, F, False, o], _Collect[I, _NativeUnaryRef[A, R, Never, F, False, o]]] == _ParOf[I]._LoopError[V, _ErrorProbe[A, R, Never], _Collect[I, _ErrorProbe[A, R, Never]]]
    return _limited_as[_ParOf[I]._LoopError[V, _ErrorProbe[A, R, Never], _Collect[I, _ErrorProbe[A, R, Never]]], _ParOf[I], V, _NativeUnaryRef[A, R, Never, F, False, o], _Collect[I, _NativeUnaryRef[A, R, Never, F, False, o]]](limit, _NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), source^)


@always_inline
def par_traverse_n[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, I: Functor = _NativeFamily[R], E: Movable & Deinitable = Never, F: def(var A) raises E -> R = def(var A) raises E -> R](limit: Int, var source: V, ref[o] function: F) raises _ParOf[I]._LoopError[V, _ErrorProbe[A, R, E], _Collect[I, _ErrorProbe[A, R, E]]] -> _ParOf[I]._Looped[V, _NativeUnaryRef[A, R, E, F, True, o], _Collect[I, _NativeUnaryRef[A, R, E, F, True, o]]] where conforms_to(I, Parallel) and downcast[_Source[V].Element, Movable & Deinitable] == A and conforms_to(_ParOf[I], _LimitedLoop) and _ParOf[I].CollectCompatible[V, _NativeUnaryRef[A, R, E, F, True, o]] and _ParOf[I]._LoopCompatible[V, _NativeUnaryRef[A, R, E, F, True, o], _Collect[I, _NativeUnaryRef[A, R, E, F, True, o]]]:
    """Admit a closure callback that raises; the family's limited loop executes."""
    _check_limit(limit, "par_traverse_n")
    comptime assert _ParOf[I]._LoopError[V, _NativeUnaryRef[A, R, E, F, True, o], _Collect[I, _NativeUnaryRef[A, R, E, F, True, o]]] == _ParOf[I]._LoopError[V, _ErrorProbe[A, R, E], _Collect[I, _ErrorProbe[A, R, E]]]
    return _limited_as[_ParOf[I]._LoopError[V, _ErrorProbe[A, R, E], _Collect[I, _ErrorProbe[A, R, E]]], _ParOf[I], V, _NativeUnaryRef[A, R, E, F, True, o], _Collect[I, _NativeUnaryRef[A, R, E, F, True, o]]](limit, _NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), source^)


def par_traverse_n[V: Movable & Deinitable, R: Movable & Deinitable, //, I: Functor = _NativeFamily[R]](limit: Int, var source: V, function: def(var _NativeOwnedArg[downcast[_Source[V].Element, Movable & Deinitable]]) thin -> R) raises _ParOf[I]._LoopError[V, _ErrorProbe[NoneType, R, Never], _Collect[I, _ErrorProbe[NoneType, R, Never]]] -> _ParOf[I]._Looped[V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False], _Collect[I, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False]]] where conforms_to(I, Parallel) and not conforms_to(R, RegisterPassable) and conforms_to(_ParOf[I], _LimitedLoop) and _ParOf[I].CollectCompatible[V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False]] and _ParOf[I]._LoopCompatible[V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False], _Collect[I, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False]]]:
    """Admit a thin callback; the family's limited loop executes."""
    _check_limit(limit, "par_traverse_n")
    comptime assert _ParOf[I]._LoopError[V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False], _Collect[I, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False]]] == _ParOf[I]._LoopError[V, _ErrorProbe[NoneType, R, Never], _Collect[I, _ErrorProbe[NoneType, R, Never]]]
    return _limited_as[_ParOf[I]._LoopError[V, _ErrorProbe[NoneType, R, Never], _Collect[I, _ErrorProbe[NoneType, R, Never]]], _ParOf[I], V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False], _Collect[I, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False]]](limit, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False](function), source^)


def par_traverse_n[V: Movable & Deinitable, R: RegisterPassable & Deinitable, //, I: Functor = _NativeFamily[R]](limit: Int, var source: V, function: def(var _NativeOwnedArg[downcast[_Source[V].Element, Movable & Deinitable]]) thin -> R) raises _ParOf[I]._LoopError[V, _ErrorProbe[NoneType, R, Never], _Collect[I, _ErrorProbe[NoneType, R, Never]]] -> _ParOf[I]._Looped[V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False], _Collect[I, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False]]] where conforms_to(I, Parallel) and conforms_to(_ParOf[I], _LimitedLoop) and _ParOf[I].CollectCompatible[V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False]] and _ParOf[I]._LoopCompatible[V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False], _Collect[I, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False]]]:
    """Admit a thin callback; the family's limited loop executes."""
    _check_limit(limit, "par_traverse_n")
    comptime assert _ParOf[I]._LoopError[V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False], _Collect[I, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False]]] == _ParOf[I]._LoopError[V, _ErrorProbe[NoneType, R, Never], _Collect[I, _ErrorProbe[NoneType, R, Never]]]
    return _limited_as[_ParOf[I]._LoopError[V, _ErrorProbe[NoneType, R, Never], _Collect[I, _ErrorProbe[NoneType, R, Never]]], _ParOf[I], V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False], _Collect[I, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False]]](limit, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False](function), source^)


def par_traverse_n[V: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, I: Functor = _NativeFamily[R]](limit: Int, var source: V, function: def(var _NativeOwnedArg[downcast[_Source[V].Element, Movable & Deinitable]]) raises E thin -> R) raises _ParOf[I]._LoopError[V, _ErrorProbe[NoneType, R, E], _Collect[I, _ErrorProbe[NoneType, R, E]]] -> _ParOf[I]._Looped[V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, E, type_of(function), True], _Collect[I, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, E, type_of(function), True]]] where conforms_to(I, Parallel) and conforms_to(_ParOf[I], _LimitedLoop) and _ParOf[I].CollectCompatible[V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, E, type_of(function), True]] and _ParOf[I]._LoopCompatible[V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, E, type_of(function), True], _Collect[I, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, E, type_of(function), True]]]:
    """Admit a thin callback that raises; the family's limited loop executes."""
    _check_limit(limit, "par_traverse_n")
    comptime assert _ParOf[I]._LoopError[V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, E, type_of(function), True], _Collect[I, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, E, type_of(function), True]]] == _ParOf[I]._LoopError[V, _ErrorProbe[NoneType, R, E], _Collect[I, _ErrorProbe[NoneType, R, E]]]
    return _limited_as[_ParOf[I]._LoopError[V, _ErrorProbe[NoneType, R, E], _Collect[I, _ErrorProbe[NoneType, R, E]]], _ParOf[I], V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, E, type_of(function), True], _Collect[I, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, E, type_of(function), True]]](limit, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, E, type_of(function), True](function), source^)


def par_traverse_void_n[V: Movable & Deinitable, F: _UnaryViewable, o: ImmOrigin, //, I: Functor = _ViewFamily[F, o]](limit: Int, var source: V, ref[o] function: F) raises _ParOf[I]._LoopError[V, F._View[o], _Void[I, F._View[o]]] -> _ParOf[I]._Looped[V, F._View[o], _Void[I, F._View[o]]] where conforms_to(I, Parallel) and _Source[V].Element == F._View[o].Arg and conforms_to(_ParOf[I], _LimitedLoop) and _ParOf[I].CollectCompatible[V, F._View[o]] and _ParOf[I]._LoopCompatible[V, F._View[o], _Void[I, F._View[o]]]:
    """Admit a view callback; the family's limited loop executes."""
    _check_limit(limit, "par_traverse_void_n")
    comptime assert _ParOf[I]._LoopError[V, F._View[o], _Void[I, F._View[o]]] == _ParOf[I]._LoopError[V, F._View[o], _Void[I, F._View[o]]]
    return _limited_as[_ParOf[I]._LoopError[V, F._View[o], _Void[I, F._View[o]]], _ParOf[I], V, F._View[o], _Void[I, F._View[o]]](limit, function._unary_view(), source^)


@always_inline
def par_traverse_void_n[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, I: Functor = _NativeFamily[R], F: def(var A) -> R = def(var A) -> R](limit: Int, var source: V, ref[o] function: F) raises _ParOf[I]._LoopError[V, _ErrorProbe[A, R, Never], _Void[I, _ErrorProbe[A, R, Never]]] -> _ParOf[I]._Looped[V, _NativeUnaryRef[A, R, Never, F, False, o], _Void[I, _NativeUnaryRef[A, R, Never, F, False, o]]] where conforms_to(I, Parallel) and downcast[_Source[V].Element, Movable & Deinitable] == A and conforms_to(_ParOf[I], _LimitedLoop) and _ParOf[I].CollectCompatible[V, _NativeUnaryRef[A, R, Never, F, False, o]] and _ParOf[I]._LoopCompatible[V, _NativeUnaryRef[A, R, Never, F, False, o], _Void[I, _NativeUnaryRef[A, R, Never, F, False, o]]]:
    """Admit a closure callback; the family's limited loop executes."""
    _check_limit(limit, "par_traverse_void_n")
    comptime assert _ParOf[I]._LoopError[V, _NativeUnaryRef[A, R, Never, F, False, o], _Void[I, _NativeUnaryRef[A, R, Never, F, False, o]]] == _ParOf[I]._LoopError[V, _ErrorProbe[A, R, Never], _Void[I, _ErrorProbe[A, R, Never]]]
    return _limited_as[_ParOf[I]._LoopError[V, _ErrorProbe[A, R, Never], _Void[I, _ErrorProbe[A, R, Never]]], _ParOf[I], V, _NativeUnaryRef[A, R, Never, F, False, o], _Void[I, _NativeUnaryRef[A, R, Never, F, False, o]]](limit, _NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function)), source^)


@always_inline
def par_traverse_void_n[V: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //, I: Functor = _NativeFamily[R], E: Movable & Deinitable = Never, F: def(var A) raises E -> R = def(var A) raises E -> R](limit: Int, var source: V, ref[o] function: F) raises _ParOf[I]._LoopError[V, _ErrorProbe[A, R, E], _Void[I, _ErrorProbe[A, R, E]]] -> _ParOf[I]._Looped[V, _NativeUnaryRef[A, R, E, F, True, o], _Void[I, _NativeUnaryRef[A, R, E, F, True, o]]] where conforms_to(I, Parallel) and downcast[_Source[V].Element, Movable & Deinitable] == A and conforms_to(_ParOf[I], _LimitedLoop) and _ParOf[I].CollectCompatible[V, _NativeUnaryRef[A, R, E, F, True, o]] and _ParOf[I]._LoopCompatible[V, _NativeUnaryRef[A, R, E, F, True, o], _Void[I, _NativeUnaryRef[A, R, E, F, True, o]]]:
    """Admit a closure callback that raises; the family's limited loop executes."""
    _check_limit(limit, "par_traverse_void_n")
    comptime assert _ParOf[I]._LoopError[V, _NativeUnaryRef[A, R, E, F, True, o], _Void[I, _NativeUnaryRef[A, R, E, F, True, o]]] == _ParOf[I]._LoopError[V, _ErrorProbe[A, R, E], _Void[I, _ErrorProbe[A, R, E]]]
    return _limited_as[_ParOf[I]._LoopError[V, _ErrorProbe[A, R, E], _Void[I, _ErrorProbe[A, R, E]]], _ParOf[I], V, _NativeUnaryRef[A, R, E, F, True, o], _Void[I, _NativeUnaryRef[A, R, E, F, True, o]]](limit, _NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function)), source^)


def par_traverse_void_n[V: Movable & Deinitable, R: Movable & Deinitable, //, I: Functor = _NativeFamily[R]](limit: Int, var source: V, function: def(var _NativeOwnedArg[downcast[_Source[V].Element, Movable & Deinitable]]) thin -> R) raises _ParOf[I]._LoopError[V, _ErrorProbe[NoneType, R, Never], _Void[I, _ErrorProbe[NoneType, R, Never]]] -> _ParOf[I]._Looped[V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False], _Void[I, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False]]] where conforms_to(I, Parallel) and not conforms_to(R, RegisterPassable) and conforms_to(_ParOf[I], _LimitedLoop) and _ParOf[I].CollectCompatible[V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False]] and _ParOf[I]._LoopCompatible[V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False], _Void[I, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False]]]:
    """Admit a thin callback; the family's limited loop executes."""
    _check_limit(limit, "par_traverse_void_n")
    comptime assert _ParOf[I]._LoopError[V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False], _Void[I, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False]]] == _ParOf[I]._LoopError[V, _ErrorProbe[NoneType, R, Never], _Void[I, _ErrorProbe[NoneType, R, Never]]]
    return _limited_as[_ParOf[I]._LoopError[V, _ErrorProbe[NoneType, R, Never], _Void[I, _ErrorProbe[NoneType, R, Never]]], _ParOf[I], V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False], _Void[I, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False]]](limit, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False](function), source^)


def par_traverse_void_n[V: Movable & Deinitable, R: RegisterPassable & Deinitable, //, I: Functor = _NativeFamily[R]](limit: Int, var source: V, function: def(var _NativeOwnedArg[downcast[_Source[V].Element, Movable & Deinitable]]) thin -> R) raises _ParOf[I]._LoopError[V, _ErrorProbe[NoneType, R, Never], _Void[I, _ErrorProbe[NoneType, R, Never]]] -> _ParOf[I]._Looped[V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False], _Void[I, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False]]] where conforms_to(I, Parallel) and conforms_to(_ParOf[I], _LimitedLoop) and _ParOf[I].CollectCompatible[V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False]] and _ParOf[I]._LoopCompatible[V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False], _Void[I, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False]]]:
    """Admit a thin callback; the family's limited loop executes."""
    _check_limit(limit, "par_traverse_void_n")
    comptime assert _ParOf[I]._LoopError[V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False], _Void[I, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False]]] == _ParOf[I]._LoopError[V, _ErrorProbe[NoneType, R, Never], _Void[I, _ErrorProbe[NoneType, R, Never]]]
    return _limited_as[_ParOf[I]._LoopError[V, _ErrorProbe[NoneType, R, Never], _Void[I, _ErrorProbe[NoneType, R, Never]]], _ParOf[I], V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False], _Void[I, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False]]](limit, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, Never, type_of(function), False](function), source^)


def par_traverse_void_n[V: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, I: Functor = _NativeFamily[R]](limit: Int, var source: V, function: def(var _NativeOwnedArg[downcast[_Source[V].Element, Movable & Deinitable]]) raises E thin -> R) raises _ParOf[I]._LoopError[V, _ErrorProbe[NoneType, R, E], _Void[I, _ErrorProbe[NoneType, R, E]]] -> _ParOf[I]._Looped[V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, E, type_of(function), True], _Void[I, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, E, type_of(function), True]]] where conforms_to(I, Parallel) and conforms_to(_ParOf[I], _LimitedLoop) and _ParOf[I].CollectCompatible[V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, E, type_of(function), True]] and _ParOf[I]._LoopCompatible[V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, E, type_of(function), True], _Void[I, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, E, type_of(function), True]]]:
    """Admit a thin callback that raises; the family's limited loop executes."""
    _check_limit(limit, "par_traverse_void_n")
    comptime assert _ParOf[I]._LoopError[V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, E, type_of(function), True], _Void[I, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, E, type_of(function), True]]] == _ParOf[I]._LoopError[V, _ErrorProbe[NoneType, R, E], _Void[I, _ErrorProbe[NoneType, R, E]]]
    return _limited_as[_ParOf[I]._LoopError[V, _ErrorProbe[NoneType, R, E], _Void[I, _ErrorProbe[NoneType, R, E]]], _ParOf[I], V, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, E, type_of(function), True], _Void[I, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, E, type_of(function), True]]](limit, NativeUnary[downcast[_Source[V].Element, Movable & Deinitable], R, E, type_of(function), True](function), source^)


# --- end native parallel admission ---
