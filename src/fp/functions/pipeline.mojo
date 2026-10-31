"""Immediate pipelines; the same planning and traversal serve stored compositions.

A stage is a plain function, a closure promoted with `as_unary`, or a `Unary`
library value such as a `Partial` or a `Composition`. Each stage's own contract
fixes its types. `pipeline(value).then(f)` chains stages one call at a time,
with no stage limit.
"""
from fp.callables.native import _call_native_never, _Thin1F, NativeUnary
from std.builtin.variadics import TypeList
from std.builtin.rebind import rebind_var
from fp.data import Result
from fp.callables.protocols import Unary
from fp._internal.errors import _CommonError
from ._pipeline import _PipelineRunner, _pipe_at
from .composition import Composition
from ._stages import _Plan, _check_stage, _stage_shared


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
        with `flow`, or chain them with `pipeline(value).then(...)`. Longer mixed calls and explicit
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
