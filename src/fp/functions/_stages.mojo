"""Stage metadata and invocation shared by pipelines and stored compositions.

A stage is a fixed-arity library callable (`Thunk`, `Unary`, `Binary` in any
receiver mode). Native functions arrive as such values: closures through
`as_unary`, plain functions through the fixed-arity overloads. Each stage's own
contract fixes its argument, result and error types, so a chain's types need no
binding plan.
"""
from std.builtin.variadics import TypeList
from std.builtin.rebind import downcast, rebind_var
from fp.callables.protocols import (UnaryContract, Unary, MutableUnary, OnceUnary,
    BinaryContract, Binary, MutableBinary, OnceBinary,
    ThunkContract, Thunk, MutableThunk, OnceThunk)
from fp._internal.errors import _ErrorCompatible, _propagate_error
from std.reflection import reflect


comptime _IsUnary[F: Movable & Deinitable] = conforms_to(F, UnaryContract)
comptime _IsBinary[F: Movable & Deinitable] = conforms_to(F, BinaryContract)
comptime _IsThunk[F: Movable & Deinitable] = conforms_to(F, ThunkContract)

# Receiver capabilities.
comptime _Shared[F: Movable & Deinitable] = (
    conforms_to(F, Unary) or conforms_to(F, Binary) or conforms_to(F, Thunk)
)
comptime _Mutable[F: Movable & Deinitable] = (
    _Shared[F] or conforms_to(F, MutableUnary) or conforms_to(F, MutableBinary) or conforms_to(F, MutableThunk)
)
comptime _Once[F: Movable & Deinitable] = (
    _Mutable[F] or conforms_to(F, OnceUnary) or conforms_to(F, OnceBinary) or conforms_to(F, OnceThunk)
)

# The number of arguments a stage takes: 0, 1 or 2; -1 when it is not a stage.
comptime _Arity[F: Movable & Deinitable]: Int = (
    1 if _IsUnary[F] else 2 if _IsBinary[F] else 0 if _IsThunk[F] else -1
)

comptime _StageIn[F: Movable & Deinitable]: Movable & Deinitable = (
    downcast[F, UnaryContract].Arg if _IsUnary[F] else NoneType
)
comptime _StageOut[F: Movable & Deinitable]: Movable & Deinitable = (
    downcast[F, UnaryContract].Out if _IsUnary[F] else
    downcast[F, BinaryContract].Out if _IsBinary[F] else
    downcast[F, ThunkContract].Out if _IsThunk[F] else NoneType
)
comptime _StageError[F: Movable & Deinitable]: Movable & Deinitable = (
    downcast[F, UnaryContract].Error if _IsUnary[F] else
    downcast[F, BinaryContract].Error if _IsBinary[F] else
    downcast[F, ThunkContract].Error if _IsThunk[F] else Never
)


struct _Plan[*Fs: Movable & Deinitable]:
    """Types of a chain whose stages are listed in execution order."""
    comptime StageOut[index: Int]: Movable & Deinitable = _StageOut[Self.Fs[index]]
    comptime StageError[index: Int]: Movable & Deinitable = _StageError[Self.Fs[index]]
    comptime Results = TypeList.tabulate[Self.Fs.length, Self.StageOut[_]]()
    comptime Errors = TypeList.tabulate[Self.Fs.length, Self.StageError[_]]()
    comptime Inhabited[T: Movable & Deinitable, index: Int] = T != Never
    comptime Raised = Self.Errors.filter_idx[Self.Inhabited[_, _]]()
    comptime Failure: Movable & Deinitable = Never if Self.Raised.length == 0 else Self.Raised[0]
    comptime Result: Movable & Deinitable = Self.Results[Self.Results.length - 1]


def _type_name[T: AnyType]() -> String:
    # Reflection spells Never as an internal stub and Int as its SIMD alias.
    comptime if T == Never:
        return "Never"
    elif T == Int:
        return "Int"
    else:
        return reflect[T].name()


def _raised[E: AnyType]() -> String:
    return "nothing" if E == Never else _type_name[E]()


def _stage_label[name: StaticString, index: Int, argument: Int]() -> String:
    # Stages count in run order; compose also names the argument, which it reverses.
    var label = String(name) + ": stage " + String(index)
    comptime if argument >= 0:
        label += " (argument " + String(argument) + ")"
    return label


def _stage_diagnostic[name: StaticString, index: Int, argument: Int, F: Movable & Deinitable,
                      A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable]() -> String:
    # The chain's expectation for this stage, then the stage's own signature.
    var allowed = "nothing" if E == Never else _type_name[E]() + " or nothing"
    return (_stage_label[name, index, argument]() + " should take " + _type_name[A]() + ", return "
            + _type_name[R]() + " and raise " + allowed + "; it takes " + _type_name[_StageIn[F]]()
            + ", returns " + _type_name[_StageOut[F]]() + " and raises " + _raised[_StageError[F]]())


def _check_stage[index: Int, F: Movable & Deinitable, A: Movable & Deinitable,
                 R: Movable & Deinitable, E: Movable & Deinitable,
                 name: StaticString = "pipe", argument: Int = -1]() -> Bool:
    comptime assert _Arity[F] == 1, (_stage_label[name, index, argument]()
        + " must take one argument: a Unary value, or a native function promoted with as_unary."
        + " Plain functions are accepted unpromoted only when every stage is one")
    comptime assert _StageIn[F] == A and _StageOut[F] == R and _ErrorCompatible[E, _StageError[F]], (
        _stage_diagnostic[name, index, argument, F, A, R, E]())
    return True


def _stage_shared[R: Movable & Deinitable, E: Movable & Deinitable,
                  F: Movable & Deinitable, A: Movable & Deinitable](function: F, var value: A
) raises E -> R:
    """Call a one-argument stage through a shared receiver."""
    comptime assert _Shared[F], "pipeline: a shared call requires a reusable shared stage"
    comptime assert _StageIn[F] == A and _StageOut[F] == R and _ErrorCompatible[E, _StageError[F]]
    comptime U = downcast[F, Unary]
    try:
        return rebind_var[R](rebind[U](function).call(rebind_var[U.Arg](value^)))
    except error:
        comptime assert _ErrorCompatible[E, type_of(error)]
        _propagate_error[E](error^)


def _stage_mutable[R: Movable & Deinitable, E: Movable & Deinitable,
                   F: Movable & Deinitable, A: Movable & Deinitable](mut function: F, var value: A
) raises E -> R:
    """Call a one-argument stage through exclusive access when it has that mode."""
    comptime assert _Mutable[F], "pipeline: a mutable call cannot reuse a consuming stage"
    comptime if conforms_to(F, MutableUnary):
        comptime U = downcast[F, MutableUnary]
        comptime assert U.Arg == A and U.Out == R and _ErrorCompatible[E, U.Error]
        try:
            return rebind_var[R](rebind[U](function).call_mut(rebind_var[U.Arg](value^)))
        except error:
            comptime assert _ErrorCompatible[E, type_of(error)]
            _propagate_error[E](error^)
    else:
        return _stage_shared[R, E](function, value^)


def _stage_once[R: Movable & Deinitable, E: Movable & Deinitable,
                F: Movable & Deinitable, A: Movable & Deinitable](mut cell: Optional[F], var value: A
) raises E -> R:
    """Call a one-argument stage once, consuming it when it has that mode."""
    comptime assert _Once[F], "pipeline: stage has no receiver mode"
    comptime if conforms_to(F, OnceUnary):
        comptime U = downcast[F, OnceUnary]
        comptime assert U.Arg == A and U.Out == R and _ErrorCompatible[E, U.Error]
        comptime assert Optional[F] == Optional[U]
        try:
            return rebind_var[R](rebind[Optional[U]](cell).take().call_once(rebind_var[U.Arg](value^)))
        except error:
            comptime assert _ErrorCompatible[E, type_of(error)]
            _propagate_error[E](error^)
    else:
        return _stage_mutable[R, E](cell.value(), value^)


# A composition's first stage may also take no argument or two arguments.
# Shared calls read the stage; exclusive and consuming calls need mutable access.
def _first_thunk_shared[R: Movable & Deinitable, E: Movable & Deinitable, F: Movable & Deinitable](
    cell: Optional[F]
) raises E -> R:
    comptime assert conforms_to(F, Thunk), "composition: a shared call requires a shared first stage"
    comptime T = downcast[F, Thunk]
    comptime assert T.Out == R and _ErrorCompatible[E, T.Error]
    try:
        return rebind_var[R](rebind[T](cell.value()).call())
    except error:
        comptime assert _ErrorCompatible[E, type_of(error)]
        _propagate_error[E](error^)


def _first_thunk_mut[R: Movable & Deinitable, E: Movable & Deinitable, F: Movable & Deinitable, once: Bool](
    mut cell: Optional[F]
) raises E -> R:
    comptime if once and conforms_to(F, OnceThunk):
        comptime T = downcast[F, OnceThunk]
        comptime assert T.Out == R and _ErrorCompatible[E, T.Error]
        try:
            return rebind_var[R](rebind[Optional[T]](cell).take().call_once())
        except error:
            comptime assert _ErrorCompatible[E, type_of(error)]
            _propagate_error[E](error^)
    elif conforms_to(F, MutableThunk):
        comptime T = downcast[F, MutableThunk]
        comptime assert T.Out == R and _ErrorCompatible[E, T.Error]
        try:
            return rebind_var[R](rebind[T](cell.value()).call_mut())
        except error:
            comptime assert _ErrorCompatible[E, type_of(error)]
            _propagate_error[E](error^)
    else:
        return _first_thunk_shared[R, E](cell)


def _first_binary_shared[R: Movable & Deinitable, E: Movable & Deinitable, F: Movable & Deinitable,
                         A: Movable & Deinitable, B: Movable & Deinitable](
    cell: Optional[F], var first: A, var second: B
) raises E -> R:
    comptime assert conforms_to(F, Binary), "composition: a shared call requires a shared first stage"
    comptime T = downcast[F, Binary]
    comptime assert T.First == A and T.Second == B and T.Out == R and _ErrorCompatible[E, T.Error]
    try:
        return rebind_var[R](rebind[T](cell.value()).call(rebind_var[T.First](first^), rebind_var[T.Second](second^)))
    except error:
        comptime assert _ErrorCompatible[E, type_of(error)]
        _propagate_error[E](error^)


def _first_binary_mut[R: Movable & Deinitable, E: Movable & Deinitable, F: Movable & Deinitable, once: Bool,
                      A: Movable & Deinitable, B: Movable & Deinitable](
    mut cell: Optional[F], var first: A, var second: B
) raises E -> R:
    comptime if once and conforms_to(F, OnceBinary):
        comptime T = downcast[F, OnceBinary]
        comptime assert T.First == A and T.Second == B and T.Out == R and _ErrorCompatible[E, T.Error]
        try:
            return rebind_var[R](rebind[Optional[T]](cell).take().call_once(
                rebind_var[T.First](first^), rebind_var[T.Second](second^)))
        except error:
            comptime assert _ErrorCompatible[E, type_of(error)]
            _propagate_error[E](error^)
    elif conforms_to(F, MutableBinary):
        comptime T = downcast[F, MutableBinary]
        comptime assert T.First == A and T.Second == B and T.Out == R and _ErrorCompatible[E, T.Error]
        try:
            return rebind_var[R](rebind[T](cell.value()).call_mut(
                rebind_var[T.First](first^), rebind_var[T.Second](second^)))
        except error:
            comptime assert _ErrorCompatible[E, type_of(error)]
            _propagate_error[E](error^)
    else:
        return _first_binary_shared[R, E](cell, first^, second^)


# Native all_conforms_to carries capability evidence through variadic type
# metadata. An ordinary Bool-returning loop does not carry that evidence.
trait _SharedCapability:
    ...
trait _MutableCapability:
    ...
trait _OnceCapability:
    ...
struct _Capabilities[F: Movable & Deinitable](
    _SharedCapability where _Shared[F],
    _MutableCapability where _Mutable[F],
    _OnceCapability where _Once[F]
):
    ...
comptime _Classify[F: Movable & Deinitable]: AnyType = _Capabilities[F]
