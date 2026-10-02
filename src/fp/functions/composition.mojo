"""Stored compositions: one tuple of stages, one plan, one pipeline traversal."""
from std.builtin.variadics import TypeList
from std.builtin.rebind import downcast, rebind_var
from fp.callables.protocols import (UnaryContract, Unary, MutableUnary, OnceUnary,
    BinaryContract, Binary, MutableBinary, OnceBinary, ThunkContract, Thunk, MutableThunk, OnceThunk)
from ._stages import (_Plan, _Arity, _StageIn, _Classify, _SharedCapability, _MutableCapability,
    _OnceCapability, _Once, _check_stage, _stage_shared, _stage_mutable, _stage_once,
    _first_thunk_shared, _first_thunk_mut, _first_binary_shared, _first_binary_mut)
from .pipeline import _PipelineRunner, _pipe_at
from fp.callables.native import _Thin0F, _Thin1F, _Thin2F


comptime _Cell[T: Movable & Deinitable]: Movable & Deinitable = Optional[T]

comptime _AllShared[Fs: TypeList[Trait=Movable & Deinitable, ...]] = Fs.map[_Classify]().all_conforms_to[_SharedCapability]()
comptime _AllMutable[Fs: TypeList[Trait=Movable & Deinitable, ...]] = Fs.map[_Classify]().all_conforms_to[_MutableCapability]()
comptime _AllOnce[Fs: TypeList[Trait=Movable & Deinitable, ...]] = Fs.map[_Classify]().all_conforms_to[_OnceCapability]()


def _stored_cell[index: Int, reverse: Bool, arity: Int, origin: Origin, *Fs: Movable & Deinitable](
    pointer: Pointer[Composition[reverse, arity, *Fs], origin]
) -> ref[origin] Optional[Fs[Fs.length - index - 1 if reverse else index]]:
    """The stage that runs at position `index`."""
    comptime C = Composition[reverse, arity, *Fs]
    comptime physical = Fs.length - index - 1 if reverse else index
    comptime assert C.Cells[physical] == Optional[Fs[physical]]
    # Reflection keeps the reference's origin that of the whole composition.
    ref cells = rebind[Tuple[*C.Cells]](reflect[C].field_ref[reflect[C].field_index["_cells"]()](pointer[]))
    return rebind[Optional[Fs[physical]]](cells[physical])


struct _StoredShared[reverse: Bool, arity: Int, origin: ImmOrigin, *Fs: Movable & Deinitable](_PipelineRunner):
    @staticmethod
    def apply[index: Int, R: Movable & Deinitable, E: Movable & Deinitable,
              A: Movable & Deinitable, *Environment: Movable & Deinitable](
        var value: A, *environment: *Environment
    ) raises E -> R:
        comptime P = Pointer[Composition[Self.reverse, Self.arity, *Self.Fs], Self.origin]
        comptime assert Environment.length == 1 and Environment[0] == P, "pipeline: exact storage origin required"
        return _stage_shared[R, E](_stored_cell[index](rebind[P](environment[0])).value(), value^)


struct _StoredExclusive[reverse: Bool, arity: Int, once: Bool, origin: MutOrigin, *Fs: Movable & Deinitable](_PipelineRunner):
    # A distinct native MutOrigin boundary retains exclusive access in the
    # parameterized runner; traversal and tuple projection remain shared.
    @staticmethod
    def apply[index: Int, R: Movable & Deinitable, E: Movable & Deinitable,
              A: Movable & Deinitable, *Environment: Movable & Deinitable](
        var value: A, *environment: *Environment
    ) raises E -> R:
        comptime P = Pointer[Composition[Self.reverse, Self.arity, *Self.Fs], Self.origin]
        comptime assert Environment.length == 1 and Environment[0] == P, "pipeline: exact storage origin required"
        comptime if Self.once:
            return _stage_once[R, E](_stored_cell[index](rebind[P](environment[0])), value^)
        else:
            return _stage_mutable[R, E](_stored_cell[index](rebind[P](environment[0])).value(), value^)


@fieldwise_init
struct Composition[reverse: Bool, arity: Int, *Fs: Movable & Deinitable](
    Movable, Copyable where Fs.map[_Cell]().all_conforms_to[Copyable](),
    ThunkContract where arity == 0,
    UnaryContract where arity == 1,
    BinaryContract where arity == 2,
    Thunk where arity == 0 and _AllShared[Fs],
    MutableThunk where arity == 0 and _AllMutable[Fs],
    OnceThunk where arity == 0 and _AllOnce[Fs],
    Unary where arity == 1 and _AllShared[Fs],
    MutableUnary where arity == 1 and _AllMutable[Fs],
    OnceUnary where arity == 1 and _AllOnce[Fs],
    Binary where arity == 2 and _AllShared[Fs],
    MutableBinary where arity == 2 and _AllMutable[Fs],
    OnceBinary where arity == 2 and _AllOnce[Fs],
):
    """A stored chain of stages, returned by `flow` and `compose`.

    The first stage to run may take zero, one or two arguments (a `Thunk`,
    `Unary` or `Binary`, including plain functions and closures promoted with
    `as_unary`); every later stage takes the previous result. Calling the
    composition runs each stage once, in order, and a raised error stops it.
    It is itself a `Thunk`, `Unary` or `Binary` in each receiver mode that all
    its stages support: shared (`call`, `__call__`), exclusive (`call_mut`) or
    consuming (`call_once`). Nothing runs during construction. It is `Copyable`
    when every stage is, and copying is explicit.

    Parameters:
        reverse: True for `compose`, whose stages run right to left.
        arity: The number of arguments the first stage takes: 0, 1 or 2.
        Fs: The stage types, in the order they were passed.
    """
    comptime Cells = Self.Fs.map[_Cell]()
    comptime Stage[index: Int]: Movable & Deinitable = Self.Fs[Self.Fs.length - index - 1 if Self.reverse else index]
    comptime Ordered = TypeList.tabulate[Self.Fs.length, Self.Stage[_]]()
    comptime Plan = _Plan[*Self.Ordered]
    comptime _HeadContract = downcast[Self.Stage[0], BinaryContract]
    comptime Arg: Movable & Deinitable = _StageIn[Self.Stage[0]]
    comptime First: Movable & Deinitable = Self._HeadContract.First
    comptime Second: Movable & Deinitable = Self._HeadContract.Second
    comptime Out: Movable & Deinitable = Self.Plan.Result
    comptime Error: Movable & Deinitable = Self.Plan.Failure
    var _cells: Tuple[*Self.Cells]

    def __init__(out self, var *functions: *Self.Fs):
        comptime assert Self.Fs.length >= 2, "composition: use flow or compose for zero or one component"
        comptime assert Self.Fs.map[_Classify]().all_conforms_to[_OnceCapability](), "composition: unsupported component; use a Thunk, Unary or Binary value or as_unary, or pass only plain functions whose types line up"
        comptime assert _Arity[Self.Stage[0]] >= 0, "composition: the first stage must be a Thunk, Unary or Binary value or a native function promoted with as_unary, or every stage must be a plain function whose types line up"
        comptime assert Self.arity == _Arity[Self.Stage[0]], "composition: arity must match the first stage"
        comptime for index in range(1, Self.Fs.length):
            comptime assert _check_stage[index, Self.Stage[index], Self.Plan.StageOut[index - 1],
                                         Self.Plan.StageOut[index], Self.Error,
                                         "compose" if Self.reverse else "flow",
                                         Self.Fs.length - 1 - index if Self.reverse else -1]()
        comptime assert Self.Cells.all_conforms_to[Defaultable]()
        self._cells = Tuple[*Self.Cells]()
        @__parameter
        def store[index: Int](var function: Self.Fs[index]):
            comptime assert Self.Cells[index] == Optional[Self.Fs[index]]
            self._cells[index] = rebind_var[Self.Cells[index]](Optional(function^))
        functions^.consume_elements[store]()

    # Shared receiver.
    def call(self) raises Self.Error -> Self.Out:
        """Run the stages when the first takes no argument."""
        comptime assert Self.arity == 0, "composition: the first stage takes arguments"
        var head = _first_thunk_shared[Self.Plan.StageOut[0], Self.Error, Self.Stage[0]](
            _stored_cell[0](Pointer(to=self)))
        comptime D = _StoredShared[Self.reverse, Self.arity, origin_of(self), *Self.Fs]
        return rebind_var[Self.Out](_pipe_at[1, Self.Plan.Results, Self.Error, D](head^, Pointer(to=self)))

    def call(self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        """Run the stages on one argument.

        Args:
            arg: The first stage's argument, consumed.

        Returns:
            The last stage's result.

        Raises:
            The stages' common error; later stages do not run.
        """
        comptime assert Self.arity == 1, "composition: the first stage does not take one argument"
        comptime D = _StoredShared[Self.reverse, Self.arity, origin_of(self), *Self.Fs]
        return rebind_var[Self.Out](_pipe_at[0, Self.Plan.Results, Self.Error, D](arg^, Pointer(to=self)))

    def call(self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        """Run the stages on two arguments."""
        comptime assert Self.arity == 2, "composition: the first stage does not take two arguments"
        var head = _first_binary_shared[Self.Plan.StageOut[0], Self.Error, Self.Stage[0]](
            _stored_cell[0](Pointer(to=self)), first^, second^)
        comptime D = _StoredShared[Self.reverse, Self.arity, origin_of(self), *Self.Fs]
        return rebind_var[Self.Out](_pipe_at[1, Self.Plan.Results, Self.Error, D](head^, Pointer(to=self)))

    def __call__(self) raises Self.Error -> Self.Out:
        """Run the stages, as `call` does, when the first takes no argument."""
        return self.call()

    def __call__(self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        """Run the stages on one argument, as `call` does.

        Args:
            arg: The first stage's argument, consumed.

        Returns:
            The last stage's result.

        Raises:
            The stages' common error; later stages do not run.
        """
        return self.call(arg^)

    def __call__(self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        """Run the stages on two arguments, as `call` does."""
        return self.call(first^, second^)

    # Exclusive receiver: stages with mutable state keep it between calls.
    def call_mut(mut self) raises Self.Error -> Self.Out:
        """Run the stages with exclusive access when the first takes no argument."""
        comptime assert Self.arity == 0, "composition: the first stage takes arguments"
        var head = _first_thunk_mut[Self.Plan.StageOut[0], Self.Error, Self.Stage[0], False](
            _stored_cell[0](Pointer(to=self)))
        comptime D = _StoredExclusive[Self.reverse, Self.arity, False, origin_of(self), *Self.Fs]
        return rebind_var[Self.Out](_pipe_at[1, Self.Plan.Results, Self.Error, D](head^, Pointer(to=self)))

    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        """Run the stages on one argument with exclusive access to stages that keep state.

        Args:
            arg: The first stage's argument, consumed.

        Returns:
            The last stage's result.

        Raises:
            The stages' common error; later stages do not run.
        """
        comptime assert Self.arity == 1, "composition: the first stage does not take one argument"
        comptime D = _StoredExclusive[Self.reverse, Self.arity, False, origin_of(self), *Self.Fs]
        return rebind_var[Self.Out](_pipe_at[0, Self.Plan.Results, Self.Error, D](arg^, Pointer(to=self)))

    def call_mut(mut self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        """Run the stages on two arguments with exclusive access."""
        comptime assert Self.arity == 2, "composition: the first stage does not take two arguments"
        var head = _first_binary_mut[Self.Plan.StageOut[0], Self.Error, Self.Stage[0], False](
            _stored_cell[0](Pointer(to=self)), first^, second^)
        comptime D = _StoredExclusive[Self.reverse, Self.arity, False, origin_of(self), *Self.Fs]
        return rebind_var[Self.Out](_pipe_at[1, Self.Plan.Results, Self.Error, D](head^, Pointer(to=self)))

    # Consuming receiver: each stage is called once and may be consumed.
    def call_once(deinit self) raises Self.Error -> Self.Out:
        """Run the stages once, consuming them, when the first takes no argument."""
        comptime assert Self.arity == 0, "composition: the first stage takes arguments"
        var head = _first_thunk_mut[Self.Plan.StageOut[0], Self.Error, Self.Stage[0], True](
            _stored_cell[0](Pointer(to=self)))
        comptime D = _StoredExclusive[Self.reverse, Self.arity, True, origin_of(self), *Self.Fs]
        return rebind_var[Self.Out](_pipe_at[1, Self.Plan.Results, Self.Error, D](head^, Pointer(to=self)))

    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        """Run the stages on one argument once, consuming the composition.

        Args:
            arg: The first stage's argument, consumed.

        Returns:
            The last stage's result.

        Raises:
            The stages' common error; later stages do not run.
        """
        comptime assert Self.arity == 1, "composition: the first stage does not take one argument"
        comptime D = _StoredExclusive[Self.reverse, Self.arity, True, origin_of(self), *Self.Fs]
        return rebind_var[Self.Out](_pipe_at[0, Self.Plan.Results, Self.Error, D](arg^, Pointer(to=self)))

    def call_once(deinit self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        """Run the stages on two arguments once, consuming the composition."""
        comptime assert Self.arity == 2, "composition: the first stage does not take two arguments"
        var head = _first_binary_mut[Self.Plan.StageOut[0], Self.Error, Self.Stage[0], True](
            _stored_cell[0](Pointer(to=self)), first^, second^)
        comptime D = _StoredExclusive[Self.reverse, Self.arity, True, origin_of(self), *Self.Fs]
        return rebind_var[Self.Out](_pipe_at[1, Self.Plan.Results, Self.Error, D](head^, Pointer(to=self)))


@fieldwise_init
struct Identity[T: Movable & Deinitable](Unary, ImplicitlyCopyable):
    """The unary identity on `T`, returned by `flow[T]()` and `compose[T]()`.

    Parameters:
        T: The value type.
    """
    comptime Arg = Self.T
    comptime Out = Self.T

    def call(self, var arg: Self.Arg) -> Self.Out:
        """Return the argument unchanged.

        Args:
            arg: The value, consumed.

        Returns:
            `arg` itself.
        """
        return arg^

    def __call__(self, var arg: Self.T) -> Self.T:
        """Return the argument unchanged, as `call` does.

        Args:
            arg: The value, consumed.

        Returns:
            `arg` itself.
        """
        return arg^


def flow[T: Movable & Deinitable]() -> Identity[T]:
    """Return the identity on `T`: a composition with no stages."""
    return Identity[T]()


def flow[F: Movable & Deinitable](var function: F) -> F:
    """Return one stage unchanged, with all its capabilities."""
    comptime assert _Once[F], "composition: unsupported component; use a Thunk, Unary or Binary value or as_unary, or pass only plain functions whose types line up"
    return function^


def flow[*Fs: Movable & Deinitable](var *functions: *Fs) -> Composition[False, _Arity[Fs[0]], *Fs] where Fs.length >= 2:
    """Compose stages left to right; nothing runs until the result is called.

    `flow(f, g, h)(x)` is `h(g(f(x)))`. Two to eight plain functions are accepted
    as they are; library values such as partials, compositions and flipped
    functions, and closures promoted with `as_unary`, are accepted in any
    number. The first stage may take zero, one or two arguments; every later
    stage takes the previous result, or the call does not compile, with an
    error that names the stage.

    Limitations:
        At most eight plain functions per call, and plain functions mixed with
        library values are promoted with `as_unary`, as in `pipe`.

    Parameters:
        Fs: The stage types.

    Args:
        functions: The stages, moved into the composition.

    Returns:
        A `Composition` that runs the stages left to right.
    """
    return Composition[False, _Arity[Fs[0]], *Fs](*functions^)


def compose[T: Movable & Deinitable]() -> Identity[T]:
    """Return the identity on `T`: a composition with no stages."""
    return flow[T]()


def compose[F: Movable & Deinitable](var function: F) -> F:
    """Return one stage unchanged, with all its capabilities."""
    return flow(function^)


def compose[*Fs: Movable & Deinitable](var *functions: *Fs) -> Composition[True, _Arity[Fs[Fs.length - 1]], *Fs] where Fs.length >= 2:
    """Compose stages right to left; nothing runs until the result is called.

    `compose(h, g, f)(x)` is `h(g(f(x)))`: the last argument runs first and may
    take zero, one or two arguments. Plain functions, library values and
    promoted closures are accepted as in `flow`. A mismatched stage is reported
    by its position in the run order and its argument position.

    Limitations:
        At most eight plain functions per call, and plain functions mixed with
        library values are promoted with `as_unary`, as in `pipe`.

    Parameters:
        Fs: The stage types, in the order they are passed.

    Args:
        functions: The stages, moved into the composition.

    Returns:
        A `Composition` that runs the stages right to left.
    """
    return Composition[True, _Arity[Fs[Fs.length - 1]], *Fs](*functions^)


# --- plain-function overloads (generated) ---
# Generated by scripts/generate_plain_overloads.py; edit the generator, not this
# block. A plain function's signature is known only at a parameter of its function
# type; a variadic pack keeps the type but not the signature, so a stage's result
# cannot be inferred from it. Each stage count therefore spells one thin
# signature per stage and delegates to the variadic form. Later stages name their
# own input type (P1, P2, ...), so a mismatched call reaches the per-stage check.
# Closures use as_unary.


def flow[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, P1: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, //](
    f0: def(var A0) raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2
) -> Composition[False, 1, _Thin1F[A0, A1, E0], _Thin1F[P1, A2, E1]]:
    """Store 2 plain functions, applied left to right."""
    return flow(_Thin1F[A0, A1, E0](f0), _Thin1F[P1, A2, E1](f1))


def flow[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, //](
    f0: def(var A0) raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2, f2: def(var P2) raises E2 thin -> A3
) -> Composition[False, 1, _Thin1F[A0, A1, E0], _Thin1F[P1, A2, E1], _Thin1F[P2, A3, E2]]:
    """Store 3 plain functions, applied left to right."""
    return flow(_Thin1F[A0, A1, E0](f0), _Thin1F[P1, A2, E1](f1), _Thin1F[P2, A3, E2](f2))


def flow[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, //](
    f0: def(var A0) raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2, f2: def(var P2) raises E2 thin -> A3, f3: def(var P3) raises E3 thin -> A4
) -> Composition[False, 1, _Thin1F[A0, A1, E0], _Thin1F[P1, A2, E1], _Thin1F[P2, A3, E2], _Thin1F[P3, A4, E3]]:
    """Store 4 plain functions, applied left to right."""
    return flow(_Thin1F[A0, A1, E0](f0), _Thin1F[P1, A2, E1](f1), _Thin1F[P2, A3, E2](f2), _Thin1F[P3, A4, E3](f3))


def flow[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, //](
    f0: def(var A0) raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2, f2: def(var P2) raises E2 thin -> A3, f3: def(var P3) raises E3 thin -> A4, f4: def(var P4) raises E4 thin -> A5
) -> Composition[False, 1, _Thin1F[A0, A1, E0], _Thin1F[P1, A2, E1], _Thin1F[P2, A3, E2], _Thin1F[P3, A4, E3], _Thin1F[P4, A5, E4]]:
    """Store 5 plain functions, applied left to right."""
    return flow(_Thin1F[A0, A1, E0](f0), _Thin1F[P1, A2, E1](f1), _Thin1F[P2, A3, E2](f2), _Thin1F[P3, A4, E3](f3), _Thin1F[P4, A5, E4](f4))


def flow[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, P5: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, E5: Movable & Deinitable, //](
    f0: def(var A0) raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2, f2: def(var P2) raises E2 thin -> A3, f3: def(var P3) raises E3 thin -> A4, f4: def(var P4) raises E4 thin -> A5, f5: def(var P5) raises E5 thin -> A6
) -> Composition[False, 1, _Thin1F[A0, A1, E0], _Thin1F[P1, A2, E1], _Thin1F[P2, A3, E2], _Thin1F[P3, A4, E3], _Thin1F[P4, A5, E4], _Thin1F[P5, A6, E5]]:
    """Store 6 plain functions, applied left to right."""
    return flow(_Thin1F[A0, A1, E0](f0), _Thin1F[P1, A2, E1](f1), _Thin1F[P2, A3, E2](f2), _Thin1F[P3, A4, E3](f3), _Thin1F[P4, A5, E4](f4), _Thin1F[P5, A6, E5](f5))


def flow[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, P5: Movable & Deinitable, P6: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, E5: Movable & Deinitable, E6: Movable & Deinitable, //](
    f0: def(var A0) raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2, f2: def(var P2) raises E2 thin -> A3, f3: def(var P3) raises E3 thin -> A4, f4: def(var P4) raises E4 thin -> A5, f5: def(var P5) raises E5 thin -> A6, f6: def(var P6) raises E6 thin -> A7
) -> Composition[False, 1, _Thin1F[A0, A1, E0], _Thin1F[P1, A2, E1], _Thin1F[P2, A3, E2], _Thin1F[P3, A4, E3], _Thin1F[P4, A5, E4], _Thin1F[P5, A6, E5], _Thin1F[P6, A7, E6]]:
    """Store 7 plain functions, applied left to right."""
    return flow(_Thin1F[A0, A1, E0](f0), _Thin1F[P1, A2, E1](f1), _Thin1F[P2, A3, E2](f2), _Thin1F[P3, A4, E3](f3), _Thin1F[P4, A5, E4](f4), _Thin1F[P5, A6, E5](f5), _Thin1F[P6, A7, E6](f6))


def flow[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, A8: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, P5: Movable & Deinitable, P6: Movable & Deinitable, P7: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, E5: Movable & Deinitable, E6: Movable & Deinitable, E7: Movable & Deinitable, //](
    f0: def(var A0) raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2, f2: def(var P2) raises E2 thin -> A3, f3: def(var P3) raises E3 thin -> A4, f4: def(var P4) raises E4 thin -> A5, f5: def(var P5) raises E5 thin -> A6, f6: def(var P6) raises E6 thin -> A7, f7: def(var P7) raises E7 thin -> A8
) -> Composition[False, 1, _Thin1F[A0, A1, E0], _Thin1F[P1, A2, E1], _Thin1F[P2, A3, E2], _Thin1F[P3, A4, E3], _Thin1F[P4, A5, E4], _Thin1F[P5, A6, E5], _Thin1F[P6, A7, E6], _Thin1F[P7, A8, E7]]:
    """Store 8 plain functions, applied left to right."""
    return flow(_Thin1F[A0, A1, E0](f0), _Thin1F[P1, A2, E1](f1), _Thin1F[P2, A3, E2](f2), _Thin1F[P3, A4, E3](f3), _Thin1F[P4, A5, E4](f4), _Thin1F[P5, A6, E5](f5), _Thin1F[P6, A7, E6](f6), _Thin1F[P7, A8, E7](f7))


def flow[A1: Movable & Deinitable, A2: Movable & Deinitable, P1: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, //](
    f0: def() raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2
) -> Composition[False, 0, _Thin0F[A1, E0], _Thin1F[P1, A2, E1]]:
    """Store 2 plain functions, applied left to right."""
    return flow(_Thin0F[A1, E0](f0), _Thin1F[P1, A2, E1](f1))


def flow[A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, //](
    f0: def() raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2, f2: def(var P2) raises E2 thin -> A3
) -> Composition[False, 0, _Thin0F[A1, E0], _Thin1F[P1, A2, E1], _Thin1F[P2, A3, E2]]:
    """Store 3 plain functions, applied left to right."""
    return flow(_Thin0F[A1, E0](f0), _Thin1F[P1, A2, E1](f1), _Thin1F[P2, A3, E2](f2))


def flow[A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, //](
    f0: def() raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2, f2: def(var P2) raises E2 thin -> A3, f3: def(var P3) raises E3 thin -> A4
) -> Composition[False, 0, _Thin0F[A1, E0], _Thin1F[P1, A2, E1], _Thin1F[P2, A3, E2], _Thin1F[P3, A4, E3]]:
    """Store 4 plain functions, applied left to right."""
    return flow(_Thin0F[A1, E0](f0), _Thin1F[P1, A2, E1](f1), _Thin1F[P2, A3, E2](f2), _Thin1F[P3, A4, E3](f3))


def flow[A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, //](
    f0: def() raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2, f2: def(var P2) raises E2 thin -> A3, f3: def(var P3) raises E3 thin -> A4, f4: def(var P4) raises E4 thin -> A5
) -> Composition[False, 0, _Thin0F[A1, E0], _Thin1F[P1, A2, E1], _Thin1F[P2, A3, E2], _Thin1F[P3, A4, E3], _Thin1F[P4, A5, E4]]:
    """Store 5 plain functions, applied left to right."""
    return flow(_Thin0F[A1, E0](f0), _Thin1F[P1, A2, E1](f1), _Thin1F[P2, A3, E2](f2), _Thin1F[P3, A4, E3](f3), _Thin1F[P4, A5, E4](f4))


def flow[A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, P5: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, E5: Movable & Deinitable, //](
    f0: def() raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2, f2: def(var P2) raises E2 thin -> A3, f3: def(var P3) raises E3 thin -> A4, f4: def(var P4) raises E4 thin -> A5, f5: def(var P5) raises E5 thin -> A6
) -> Composition[False, 0, _Thin0F[A1, E0], _Thin1F[P1, A2, E1], _Thin1F[P2, A3, E2], _Thin1F[P3, A4, E3], _Thin1F[P4, A5, E4], _Thin1F[P5, A6, E5]]:
    """Store 6 plain functions, applied left to right."""
    return flow(_Thin0F[A1, E0](f0), _Thin1F[P1, A2, E1](f1), _Thin1F[P2, A3, E2](f2), _Thin1F[P3, A4, E3](f3), _Thin1F[P4, A5, E4](f4), _Thin1F[P5, A6, E5](f5))


def flow[A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, P5: Movable & Deinitable, P6: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, E5: Movable & Deinitable, E6: Movable & Deinitable, //](
    f0: def() raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2, f2: def(var P2) raises E2 thin -> A3, f3: def(var P3) raises E3 thin -> A4, f4: def(var P4) raises E4 thin -> A5, f5: def(var P5) raises E5 thin -> A6, f6: def(var P6) raises E6 thin -> A7
) -> Composition[False, 0, _Thin0F[A1, E0], _Thin1F[P1, A2, E1], _Thin1F[P2, A3, E2], _Thin1F[P3, A4, E3], _Thin1F[P4, A5, E4], _Thin1F[P5, A6, E5], _Thin1F[P6, A7, E6]]:
    """Store 7 plain functions, applied left to right."""
    return flow(_Thin0F[A1, E0](f0), _Thin1F[P1, A2, E1](f1), _Thin1F[P2, A3, E2](f2), _Thin1F[P3, A4, E3](f3), _Thin1F[P4, A5, E4](f4), _Thin1F[P5, A6, E5](f5), _Thin1F[P6, A7, E6](f6))


def flow[A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, A8: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, P5: Movable & Deinitable, P6: Movable & Deinitable, P7: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, E5: Movable & Deinitable, E6: Movable & Deinitable, E7: Movable & Deinitable, //](
    f0: def() raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2, f2: def(var P2) raises E2 thin -> A3, f3: def(var P3) raises E3 thin -> A4, f4: def(var P4) raises E4 thin -> A5, f5: def(var P5) raises E5 thin -> A6, f6: def(var P6) raises E6 thin -> A7, f7: def(var P7) raises E7 thin -> A8
) -> Composition[False, 0, _Thin0F[A1, E0], _Thin1F[P1, A2, E1], _Thin1F[P2, A3, E2], _Thin1F[P3, A4, E3], _Thin1F[P4, A5, E4], _Thin1F[P5, A6, E5], _Thin1F[P6, A7, E6], _Thin1F[P7, A8, E7]]:
    """Store 8 plain functions, applied left to right."""
    return flow(_Thin0F[A1, E0](f0), _Thin1F[P1, A2, E1](f1), _Thin1F[P2, A3, E2](f2), _Thin1F[P3, A4, E3](f3), _Thin1F[P4, A5, E4](f4), _Thin1F[P5, A6, E5](f5), _Thin1F[P6, A7, E6](f6), _Thin1F[P7, A8, E7](f7))


def flow[B0: Movable & Deinitable, B1: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, P1: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, //](
    f0: def(var B0, var B1) raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2
) -> Composition[False, 2, _Thin2F[B0, B1, A1, E0], _Thin1F[P1, A2, E1]]:
    """Store 2 plain functions, applied left to right."""
    return flow(_Thin2F[B0, B1, A1, E0](f0), _Thin1F[P1, A2, E1](f1))


def flow[B0: Movable & Deinitable, B1: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, //](
    f0: def(var B0, var B1) raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2, f2: def(var P2) raises E2 thin -> A3
) -> Composition[False, 2, _Thin2F[B0, B1, A1, E0], _Thin1F[P1, A2, E1], _Thin1F[P2, A3, E2]]:
    """Store 3 plain functions, applied left to right."""
    return flow(_Thin2F[B0, B1, A1, E0](f0), _Thin1F[P1, A2, E1](f1), _Thin1F[P2, A3, E2](f2))


def flow[B0: Movable & Deinitable, B1: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, //](
    f0: def(var B0, var B1) raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2, f2: def(var P2) raises E2 thin -> A3, f3: def(var P3) raises E3 thin -> A4
) -> Composition[False, 2, _Thin2F[B0, B1, A1, E0], _Thin1F[P1, A2, E1], _Thin1F[P2, A3, E2], _Thin1F[P3, A4, E3]]:
    """Store 4 plain functions, applied left to right."""
    return flow(_Thin2F[B0, B1, A1, E0](f0), _Thin1F[P1, A2, E1](f1), _Thin1F[P2, A3, E2](f2), _Thin1F[P3, A4, E3](f3))


def flow[B0: Movable & Deinitable, B1: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, //](
    f0: def(var B0, var B1) raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2, f2: def(var P2) raises E2 thin -> A3, f3: def(var P3) raises E3 thin -> A4, f4: def(var P4) raises E4 thin -> A5
) -> Composition[False, 2, _Thin2F[B0, B1, A1, E0], _Thin1F[P1, A2, E1], _Thin1F[P2, A3, E2], _Thin1F[P3, A4, E3], _Thin1F[P4, A5, E4]]:
    """Store 5 plain functions, applied left to right."""
    return flow(_Thin2F[B0, B1, A1, E0](f0), _Thin1F[P1, A2, E1](f1), _Thin1F[P2, A3, E2](f2), _Thin1F[P3, A4, E3](f3), _Thin1F[P4, A5, E4](f4))


def flow[B0: Movable & Deinitable, B1: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, P5: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, E5: Movable & Deinitable, //](
    f0: def(var B0, var B1) raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2, f2: def(var P2) raises E2 thin -> A3, f3: def(var P3) raises E3 thin -> A4, f4: def(var P4) raises E4 thin -> A5, f5: def(var P5) raises E5 thin -> A6
) -> Composition[False, 2, _Thin2F[B0, B1, A1, E0], _Thin1F[P1, A2, E1], _Thin1F[P2, A3, E2], _Thin1F[P3, A4, E3], _Thin1F[P4, A5, E4], _Thin1F[P5, A6, E5]]:
    """Store 6 plain functions, applied left to right."""
    return flow(_Thin2F[B0, B1, A1, E0](f0), _Thin1F[P1, A2, E1](f1), _Thin1F[P2, A3, E2](f2), _Thin1F[P3, A4, E3](f3), _Thin1F[P4, A5, E4](f4), _Thin1F[P5, A6, E5](f5))


def flow[B0: Movable & Deinitable, B1: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, P5: Movable & Deinitable, P6: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, E5: Movable & Deinitable, E6: Movable & Deinitable, //](
    f0: def(var B0, var B1) raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2, f2: def(var P2) raises E2 thin -> A3, f3: def(var P3) raises E3 thin -> A4, f4: def(var P4) raises E4 thin -> A5, f5: def(var P5) raises E5 thin -> A6, f6: def(var P6) raises E6 thin -> A7
) -> Composition[False, 2, _Thin2F[B0, B1, A1, E0], _Thin1F[P1, A2, E1], _Thin1F[P2, A3, E2], _Thin1F[P3, A4, E3], _Thin1F[P4, A5, E4], _Thin1F[P5, A6, E5], _Thin1F[P6, A7, E6]]:
    """Store 7 plain functions, applied left to right."""
    return flow(_Thin2F[B0, B1, A1, E0](f0), _Thin1F[P1, A2, E1](f1), _Thin1F[P2, A3, E2](f2), _Thin1F[P3, A4, E3](f3), _Thin1F[P4, A5, E4](f4), _Thin1F[P5, A6, E5](f5), _Thin1F[P6, A7, E6](f6))


def flow[B0: Movable & Deinitable, B1: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, A8: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, P5: Movable & Deinitable, P6: Movable & Deinitable, P7: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, E5: Movable & Deinitable, E6: Movable & Deinitable, E7: Movable & Deinitable, //](
    f0: def(var B0, var B1) raises E0 thin -> A1, f1: def(var P1) raises E1 thin -> A2, f2: def(var P2) raises E2 thin -> A3, f3: def(var P3) raises E3 thin -> A4, f4: def(var P4) raises E4 thin -> A5, f5: def(var P5) raises E5 thin -> A6, f6: def(var P6) raises E6 thin -> A7, f7: def(var P7) raises E7 thin -> A8
) -> Composition[False, 2, _Thin2F[B0, B1, A1, E0], _Thin1F[P1, A2, E1], _Thin1F[P2, A3, E2], _Thin1F[P3, A4, E3], _Thin1F[P4, A5, E4], _Thin1F[P5, A6, E5], _Thin1F[P6, A7, E6], _Thin1F[P7, A8, E7]]:
    """Store 8 plain functions, applied left to right."""
    return flow(_Thin2F[B0, B1, A1, E0](f0), _Thin1F[P1, A2, E1](f1), _Thin1F[P2, A3, E2](f2), _Thin1F[P3, A4, E3](f3), _Thin1F[P4, A5, E4](f4), _Thin1F[P5, A6, E5](f5), _Thin1F[P6, A7, E6](f6), _Thin1F[P7, A8, E7](f7))


def compose[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, P1: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, //](
    f1: def(var P1) raises E1 thin -> A2, f0: def(var A0) raises E0 thin -> A1
) -> Composition[True, 1, _Thin1F[P1, A2, E1], _Thin1F[A0, A1, E0]]:
    """Store 2 plain functions, applied right to left."""
    return compose(_Thin1F[P1, A2, E1](f1), _Thin1F[A0, A1, E0](f0))


def compose[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, //](
    f2: def(var P2) raises E2 thin -> A3, f1: def(var P1) raises E1 thin -> A2, f0: def(var A0) raises E0 thin -> A1
) -> Composition[True, 1, _Thin1F[P2, A3, E2], _Thin1F[P1, A2, E1], _Thin1F[A0, A1, E0]]:
    """Store 3 plain functions, applied right to left."""
    return compose(_Thin1F[P2, A3, E2](f2), _Thin1F[P1, A2, E1](f1), _Thin1F[A0, A1, E0](f0))


def compose[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, //](
    f3: def(var P3) raises E3 thin -> A4, f2: def(var P2) raises E2 thin -> A3, f1: def(var P1) raises E1 thin -> A2, f0: def(var A0) raises E0 thin -> A1
) -> Composition[True, 1, _Thin1F[P3, A4, E3], _Thin1F[P2, A3, E2], _Thin1F[P1, A2, E1], _Thin1F[A0, A1, E0]]:
    """Store 4 plain functions, applied right to left."""
    return compose(_Thin1F[P3, A4, E3](f3), _Thin1F[P2, A3, E2](f2), _Thin1F[P1, A2, E1](f1), _Thin1F[A0, A1, E0](f0))


def compose[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, //](
    f4: def(var P4) raises E4 thin -> A5, f3: def(var P3) raises E3 thin -> A4, f2: def(var P2) raises E2 thin -> A3, f1: def(var P1) raises E1 thin -> A2, f0: def(var A0) raises E0 thin -> A1
) -> Composition[True, 1, _Thin1F[P4, A5, E4], _Thin1F[P3, A4, E3], _Thin1F[P2, A3, E2], _Thin1F[P1, A2, E1], _Thin1F[A0, A1, E0]]:
    """Store 5 plain functions, applied right to left."""
    return compose(_Thin1F[P4, A5, E4](f4), _Thin1F[P3, A4, E3](f3), _Thin1F[P2, A3, E2](f2), _Thin1F[P1, A2, E1](f1), _Thin1F[A0, A1, E0](f0))


def compose[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, P5: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, E5: Movable & Deinitable, //](
    f5: def(var P5) raises E5 thin -> A6, f4: def(var P4) raises E4 thin -> A5, f3: def(var P3) raises E3 thin -> A4, f2: def(var P2) raises E2 thin -> A3, f1: def(var P1) raises E1 thin -> A2, f0: def(var A0) raises E0 thin -> A1
) -> Composition[True, 1, _Thin1F[P5, A6, E5], _Thin1F[P4, A5, E4], _Thin1F[P3, A4, E3], _Thin1F[P2, A3, E2], _Thin1F[P1, A2, E1], _Thin1F[A0, A1, E0]]:
    """Store 6 plain functions, applied right to left."""
    return compose(_Thin1F[P5, A6, E5](f5), _Thin1F[P4, A5, E4](f4), _Thin1F[P3, A4, E3](f3), _Thin1F[P2, A3, E2](f2), _Thin1F[P1, A2, E1](f1), _Thin1F[A0, A1, E0](f0))


def compose[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, P5: Movable & Deinitable, P6: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, E5: Movable & Deinitable, E6: Movable & Deinitable, //](
    f6: def(var P6) raises E6 thin -> A7, f5: def(var P5) raises E5 thin -> A6, f4: def(var P4) raises E4 thin -> A5, f3: def(var P3) raises E3 thin -> A4, f2: def(var P2) raises E2 thin -> A3, f1: def(var P1) raises E1 thin -> A2, f0: def(var A0) raises E0 thin -> A1
) -> Composition[True, 1, _Thin1F[P6, A7, E6], _Thin1F[P5, A6, E5], _Thin1F[P4, A5, E4], _Thin1F[P3, A4, E3], _Thin1F[P2, A3, E2], _Thin1F[P1, A2, E1], _Thin1F[A0, A1, E0]]:
    """Store 7 plain functions, applied right to left."""
    return compose(_Thin1F[P6, A7, E6](f6), _Thin1F[P5, A6, E5](f5), _Thin1F[P4, A5, E4](f4), _Thin1F[P3, A4, E3](f3), _Thin1F[P2, A3, E2](f2), _Thin1F[P1, A2, E1](f1), _Thin1F[A0, A1, E0](f0))


def compose[A0: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, A8: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, P5: Movable & Deinitable, P6: Movable & Deinitable, P7: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, E5: Movable & Deinitable, E6: Movable & Deinitable, E7: Movable & Deinitable, //](
    f7: def(var P7) raises E7 thin -> A8, f6: def(var P6) raises E6 thin -> A7, f5: def(var P5) raises E5 thin -> A6, f4: def(var P4) raises E4 thin -> A5, f3: def(var P3) raises E3 thin -> A4, f2: def(var P2) raises E2 thin -> A3, f1: def(var P1) raises E1 thin -> A2, f0: def(var A0) raises E0 thin -> A1
) -> Composition[True, 1, _Thin1F[P7, A8, E7], _Thin1F[P6, A7, E6], _Thin1F[P5, A6, E5], _Thin1F[P4, A5, E4], _Thin1F[P3, A4, E3], _Thin1F[P2, A3, E2], _Thin1F[P1, A2, E1], _Thin1F[A0, A1, E0]]:
    """Store 8 plain functions, applied right to left."""
    return compose(_Thin1F[P7, A8, E7](f7), _Thin1F[P6, A7, E6](f6), _Thin1F[P5, A6, E5](f5), _Thin1F[P4, A5, E4](f4), _Thin1F[P3, A4, E3](f3), _Thin1F[P2, A3, E2](f2), _Thin1F[P1, A2, E1](f1), _Thin1F[A0, A1, E0](f0))


def compose[A1: Movable & Deinitable, A2: Movable & Deinitable, P1: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, //](
    f1: def(var P1) raises E1 thin -> A2, f0: def() raises E0 thin -> A1
) -> Composition[True, 0, _Thin1F[P1, A2, E1], _Thin0F[A1, E0]]:
    """Store 2 plain functions, applied right to left."""
    return compose(_Thin1F[P1, A2, E1](f1), _Thin0F[A1, E0](f0))


def compose[A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, //](
    f2: def(var P2) raises E2 thin -> A3, f1: def(var P1) raises E1 thin -> A2, f0: def() raises E0 thin -> A1
) -> Composition[True, 0, _Thin1F[P2, A3, E2], _Thin1F[P1, A2, E1], _Thin0F[A1, E0]]:
    """Store 3 plain functions, applied right to left."""
    return compose(_Thin1F[P2, A3, E2](f2), _Thin1F[P1, A2, E1](f1), _Thin0F[A1, E0](f0))


def compose[A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, //](
    f3: def(var P3) raises E3 thin -> A4, f2: def(var P2) raises E2 thin -> A3, f1: def(var P1) raises E1 thin -> A2, f0: def() raises E0 thin -> A1
) -> Composition[True, 0, _Thin1F[P3, A4, E3], _Thin1F[P2, A3, E2], _Thin1F[P1, A2, E1], _Thin0F[A1, E0]]:
    """Store 4 plain functions, applied right to left."""
    return compose(_Thin1F[P3, A4, E3](f3), _Thin1F[P2, A3, E2](f2), _Thin1F[P1, A2, E1](f1), _Thin0F[A1, E0](f0))


def compose[A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, //](
    f4: def(var P4) raises E4 thin -> A5, f3: def(var P3) raises E3 thin -> A4, f2: def(var P2) raises E2 thin -> A3, f1: def(var P1) raises E1 thin -> A2, f0: def() raises E0 thin -> A1
) -> Composition[True, 0, _Thin1F[P4, A5, E4], _Thin1F[P3, A4, E3], _Thin1F[P2, A3, E2], _Thin1F[P1, A2, E1], _Thin0F[A1, E0]]:
    """Store 5 plain functions, applied right to left."""
    return compose(_Thin1F[P4, A5, E4](f4), _Thin1F[P3, A4, E3](f3), _Thin1F[P2, A3, E2](f2), _Thin1F[P1, A2, E1](f1), _Thin0F[A1, E0](f0))


def compose[A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, P5: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, E5: Movable & Deinitable, //](
    f5: def(var P5) raises E5 thin -> A6, f4: def(var P4) raises E4 thin -> A5, f3: def(var P3) raises E3 thin -> A4, f2: def(var P2) raises E2 thin -> A3, f1: def(var P1) raises E1 thin -> A2, f0: def() raises E0 thin -> A1
) -> Composition[True, 0, _Thin1F[P5, A6, E5], _Thin1F[P4, A5, E4], _Thin1F[P3, A4, E3], _Thin1F[P2, A3, E2], _Thin1F[P1, A2, E1], _Thin0F[A1, E0]]:
    """Store 6 plain functions, applied right to left."""
    return compose(_Thin1F[P5, A6, E5](f5), _Thin1F[P4, A5, E4](f4), _Thin1F[P3, A4, E3](f3), _Thin1F[P2, A3, E2](f2), _Thin1F[P1, A2, E1](f1), _Thin0F[A1, E0](f0))


def compose[A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, P5: Movable & Deinitable, P6: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, E5: Movable & Deinitable, E6: Movable & Deinitable, //](
    f6: def(var P6) raises E6 thin -> A7, f5: def(var P5) raises E5 thin -> A6, f4: def(var P4) raises E4 thin -> A5, f3: def(var P3) raises E3 thin -> A4, f2: def(var P2) raises E2 thin -> A3, f1: def(var P1) raises E1 thin -> A2, f0: def() raises E0 thin -> A1
) -> Composition[True, 0, _Thin1F[P6, A7, E6], _Thin1F[P5, A6, E5], _Thin1F[P4, A5, E4], _Thin1F[P3, A4, E3], _Thin1F[P2, A3, E2], _Thin1F[P1, A2, E1], _Thin0F[A1, E0]]:
    """Store 7 plain functions, applied right to left."""
    return compose(_Thin1F[P6, A7, E6](f6), _Thin1F[P5, A6, E5](f5), _Thin1F[P4, A5, E4](f4), _Thin1F[P3, A4, E3](f3), _Thin1F[P2, A3, E2](f2), _Thin1F[P1, A2, E1](f1), _Thin0F[A1, E0](f0))


def compose[A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, A8: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, P5: Movable & Deinitable, P6: Movable & Deinitable, P7: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, E5: Movable & Deinitable, E6: Movable & Deinitable, E7: Movable & Deinitable, //](
    f7: def(var P7) raises E7 thin -> A8, f6: def(var P6) raises E6 thin -> A7, f5: def(var P5) raises E5 thin -> A6, f4: def(var P4) raises E4 thin -> A5, f3: def(var P3) raises E3 thin -> A4, f2: def(var P2) raises E2 thin -> A3, f1: def(var P1) raises E1 thin -> A2, f0: def() raises E0 thin -> A1
) -> Composition[True, 0, _Thin1F[P7, A8, E7], _Thin1F[P6, A7, E6], _Thin1F[P5, A6, E5], _Thin1F[P4, A5, E4], _Thin1F[P3, A4, E3], _Thin1F[P2, A3, E2], _Thin1F[P1, A2, E1], _Thin0F[A1, E0]]:
    """Store 8 plain functions, applied right to left."""
    return compose(_Thin1F[P7, A8, E7](f7), _Thin1F[P6, A7, E6](f6), _Thin1F[P5, A6, E5](f5), _Thin1F[P4, A5, E4](f4), _Thin1F[P3, A4, E3](f3), _Thin1F[P2, A3, E2](f2), _Thin1F[P1, A2, E1](f1), _Thin0F[A1, E0](f0))


def compose[B0: Movable & Deinitable, B1: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, P1: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, //](
    f1: def(var P1) raises E1 thin -> A2, f0: def(var B0, var B1) raises E0 thin -> A1
) -> Composition[True, 2, _Thin1F[P1, A2, E1], _Thin2F[B0, B1, A1, E0]]:
    """Store 2 plain functions, applied right to left."""
    return compose(_Thin1F[P1, A2, E1](f1), _Thin2F[B0, B1, A1, E0](f0))


def compose[B0: Movable & Deinitable, B1: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, //](
    f2: def(var P2) raises E2 thin -> A3, f1: def(var P1) raises E1 thin -> A2, f0: def(var B0, var B1) raises E0 thin -> A1
) -> Composition[True, 2, _Thin1F[P2, A3, E2], _Thin1F[P1, A2, E1], _Thin2F[B0, B1, A1, E0]]:
    """Store 3 plain functions, applied right to left."""
    return compose(_Thin1F[P2, A3, E2](f2), _Thin1F[P1, A2, E1](f1), _Thin2F[B0, B1, A1, E0](f0))


def compose[B0: Movable & Deinitable, B1: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, //](
    f3: def(var P3) raises E3 thin -> A4, f2: def(var P2) raises E2 thin -> A3, f1: def(var P1) raises E1 thin -> A2, f0: def(var B0, var B1) raises E0 thin -> A1
) -> Composition[True, 2, _Thin1F[P3, A4, E3], _Thin1F[P2, A3, E2], _Thin1F[P1, A2, E1], _Thin2F[B0, B1, A1, E0]]:
    """Store 4 plain functions, applied right to left."""
    return compose(_Thin1F[P3, A4, E3](f3), _Thin1F[P2, A3, E2](f2), _Thin1F[P1, A2, E1](f1), _Thin2F[B0, B1, A1, E0](f0))


def compose[B0: Movable & Deinitable, B1: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, //](
    f4: def(var P4) raises E4 thin -> A5, f3: def(var P3) raises E3 thin -> A4, f2: def(var P2) raises E2 thin -> A3, f1: def(var P1) raises E1 thin -> A2, f0: def(var B0, var B1) raises E0 thin -> A1
) -> Composition[True, 2, _Thin1F[P4, A5, E4], _Thin1F[P3, A4, E3], _Thin1F[P2, A3, E2], _Thin1F[P1, A2, E1], _Thin2F[B0, B1, A1, E0]]:
    """Store 5 plain functions, applied right to left."""
    return compose(_Thin1F[P4, A5, E4](f4), _Thin1F[P3, A4, E3](f3), _Thin1F[P2, A3, E2](f2), _Thin1F[P1, A2, E1](f1), _Thin2F[B0, B1, A1, E0](f0))


def compose[B0: Movable & Deinitable, B1: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, P5: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, E5: Movable & Deinitable, //](
    f5: def(var P5) raises E5 thin -> A6, f4: def(var P4) raises E4 thin -> A5, f3: def(var P3) raises E3 thin -> A4, f2: def(var P2) raises E2 thin -> A3, f1: def(var P1) raises E1 thin -> A2, f0: def(var B0, var B1) raises E0 thin -> A1
) -> Composition[True, 2, _Thin1F[P5, A6, E5], _Thin1F[P4, A5, E4], _Thin1F[P3, A4, E3], _Thin1F[P2, A3, E2], _Thin1F[P1, A2, E1], _Thin2F[B0, B1, A1, E0]]:
    """Store 6 plain functions, applied right to left."""
    return compose(_Thin1F[P5, A6, E5](f5), _Thin1F[P4, A5, E4](f4), _Thin1F[P3, A4, E3](f3), _Thin1F[P2, A3, E2](f2), _Thin1F[P1, A2, E1](f1), _Thin2F[B0, B1, A1, E0](f0))


def compose[B0: Movable & Deinitable, B1: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, P5: Movable & Deinitable, P6: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, E5: Movable & Deinitable, E6: Movable & Deinitable, //](
    f6: def(var P6) raises E6 thin -> A7, f5: def(var P5) raises E5 thin -> A6, f4: def(var P4) raises E4 thin -> A5, f3: def(var P3) raises E3 thin -> A4, f2: def(var P2) raises E2 thin -> A3, f1: def(var P1) raises E1 thin -> A2, f0: def(var B0, var B1) raises E0 thin -> A1
) -> Composition[True, 2, _Thin1F[P6, A7, E6], _Thin1F[P5, A6, E5], _Thin1F[P4, A5, E4], _Thin1F[P3, A4, E3], _Thin1F[P2, A3, E2], _Thin1F[P1, A2, E1], _Thin2F[B0, B1, A1, E0]]:
    """Store 7 plain functions, applied right to left."""
    return compose(_Thin1F[P6, A7, E6](f6), _Thin1F[P5, A6, E5](f5), _Thin1F[P4, A5, E4](f4), _Thin1F[P3, A4, E3](f3), _Thin1F[P2, A3, E2](f2), _Thin1F[P1, A2, E1](f1), _Thin2F[B0, B1, A1, E0](f0))


def compose[B0: Movable & Deinitable, B1: Movable & Deinitable, A1: Movable & Deinitable, A2: Movable & Deinitable, A3: Movable & Deinitable, A4: Movable & Deinitable, A5: Movable & Deinitable, A6: Movable & Deinitable, A7: Movable & Deinitable, A8: Movable & Deinitable, P1: Movable & Deinitable, P2: Movable & Deinitable, P3: Movable & Deinitable, P4: Movable & Deinitable, P5: Movable & Deinitable, P6: Movable & Deinitable, P7: Movable & Deinitable, E0: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, E3: Movable & Deinitable, E4: Movable & Deinitable, E5: Movable & Deinitable, E6: Movable & Deinitable, E7: Movable & Deinitable, //](
    f7: def(var P7) raises E7 thin -> A8, f6: def(var P6) raises E6 thin -> A7, f5: def(var P5) raises E5 thin -> A6, f4: def(var P4) raises E4 thin -> A5, f3: def(var P3) raises E3 thin -> A4, f2: def(var P2) raises E2 thin -> A3, f1: def(var P1) raises E1 thin -> A2, f0: def(var B0, var B1) raises E0 thin -> A1
) -> Composition[True, 2, _Thin1F[P7, A8, E7], _Thin1F[P6, A7, E6], _Thin1F[P5, A6, E5], _Thin1F[P4, A5, E4], _Thin1F[P3, A4, E3], _Thin1F[P2, A3, E2], _Thin1F[P1, A2, E1], _Thin2F[B0, B1, A1, E0]]:
    """Store 8 plain functions, applied right to left."""
    return compose(_Thin1F[P7, A8, E7](f7), _Thin1F[P6, A7, E6](f6), _Thin1F[P5, A6, E5](f5), _Thin1F[P4, A5, E4](f4), _Thin1F[P3, A4, E3](f3), _Thin1F[P2, A3, E2](f2), _Thin1F[P1, A2, E1](f1), _Thin2F[B0, B1, A1, E0](f0))
# --- end plain-function overloads ---
