"""What a clause returns: a value, `Next` to continue with a smaller value, or a guarded result."""
from fp.adt.data import Value
from fp._internal.errors import _CommonError, _ErrorCompatible, _NativeError, _forward


trait _Continuation:
    """A clause result that continues the match with another value."""
    pass


trait _Declinable:
    """A clause result that may decline, letting the next clause try."""
    comptime Payload: Value

    def accepted(self) -> Bool:
        ...

    def take(deinit self) -> Self.Payload:
        ...


@fieldwise_init
struct Next[N: ImplicitlyCopyable & Deinitable](Movable, _Continuation):
    """The result of the matched value is the result of matching `node` instead.

    `node` must be smaller than the matched value: a sub-value, or any value of
    smaller height. Continuing with a value that is not smaller aborts, so a
    chain of `Next` steps always ends.

    Parameters:
        N: The value type, `Node[F]` for the data type being matched.
    """

    var node: Self.N
    """The value to match next."""


struct Guarded[O: Value](Movable, _Declinable):
    """The result of a `when` clause: a value when its guard held, nothing otherwise.

    Parameters:
        O: The clause's result type, or `Next`.
    """

    comptime Payload = Self.O
    var _value: Optional[Self.O]

    def __init__(out self):
        """The guard did not hold."""
        self._value = None

    def __init__(out self, var value: Self.O):
        """The guard held and the clause produced `value`.

        Args:
            value: The clause's result.
        """
        self._value = Optional(value^)

    def accepted(self) -> Bool:
        """Whether the guard held.

        Returns:
            True when the clause applied and produced a result.
        """
        return Bool(self._value)

    def take(deinit self) -> Self.O:
        """The clause's result; the guard must have held.

        Returns:
            The result the clause produced.
        """
        return self._value.take()


def when[A: AnyType, O: Value, EG: AnyType, EB: AnyType, //,
         guard: def(A) raises EG thin -> Bool, clause: def(A) raises EB thin -> O](
    a: A
) raises _CommonError[_NativeError[EG], _NativeError[EB]] -> Guarded[O]:
    """A clause that applies only when `guard` holds for the same argument.

    When the guard returns False the match tries the next clause for the same
    constructor, so a constructor still needs a clause that cannot decline.
    Literal and nested patterns are written as guards: `e.left == Literal(0)`.

    Parameters:
        A: The clause's parameter type: a constructor of the matched data type.
        O: The clause's result type, or `Next`.
        EG: The guard's error type, `Never` for a pure guard.
        EB: The clause's error type, `Never` for a pure clause.
        guard: Decides whether the clause applies.
        clause: The clause to apply.

    Args:
        a: The constructor being matched.

    Returns:
        The clause's result, or nothing when the guard does not hold.

    Raises:
        The guard's or the clause's error, unchanged; both must raise one type or `Never`.
    """
    comptime E = _CommonError[_NativeError[EG], _NativeError[EB]]
    comptime assert _ErrorCompatible[E, _NativeError[EB]], "when: the guard and the clause raise different error types"
    if not _forward[E](guard, a):
        return Guarded[O]()
    return Guarded[O](_forward[E](clause, a))


def when[A: AnyType, B: AnyType, O: Value, EG: AnyType, EB: AnyType, //,
         guard: def(A, B) raises EG thin -> Bool, clause: def(A, B) raises EB thin -> O](
    a: A, b: B
) raises _CommonError[_NativeError[EG], _NativeError[EB]] -> Guarded[O]:
    """A guarded clause with two parameters: a constructor and the context, or two subjects.

    Parameters:
        A: The first parameter type.
        B: The second parameter type.
        O: The clause's result type, or `Next`.
        EG: The guard's error type, `Never` for a pure guard.
        EB: The clause's error type, `Never` for a pure clause.
        guard: Decides whether the clause applies.
        clause: The clause to apply.

    Args:
        a: The first argument.
        b: The second argument.

    Returns:
        The clause's result, or nothing when the guard does not hold.

    Raises:
        The guard's or the clause's error, unchanged; both must raise one type or `Never`.
    """
    comptime E = _CommonError[_NativeError[EG], _NativeError[EB]]
    comptime assert _ErrorCompatible[E, _NativeError[EB]], "when: the guard and the clause raise different error types"
    if not _forward[E](guard, a, b):
        return Guarded[O]()
    return Guarded[O](_forward[E](clause, a, b))


def when[A: AnyType, B: AnyType, C: AnyType, O: Value, EG: AnyType, EB: AnyType, //,
         guard: def(A, B, C) raises EG thin -> Bool, clause: def(A, B, C) raises EB thin -> O](
    a: A, b: B, c: C
) raises _CommonError[_NativeError[EG], _NativeError[EB]] -> Guarded[O]:
    """A guarded clause with three parameters, for three subjects.

    Parameters:
        A: The first parameter type.
        B: The second parameter type.
        C: The third parameter type.
        O: The clause's result type.
        EG: The guard's error type, `Never` for a pure guard.
        EB: The clause's error type, `Never` for a pure clause.
        guard: Decides whether the clause applies.
        clause: The clause to apply.

    Args:
        a: The first argument.
        b: The second argument.
        c: The third argument.

    Returns:
        The clause's result, or nothing when the guard does not hold.

    Raises:
        The guard's or the clause's error, unchanged; both must raise one type or `Never`.
    """
    comptime E = _CommonError[_NativeError[EG], _NativeError[EB]]
    comptime assert _ErrorCompatible[E, _NativeError[EB]], "when: the guard and the clause raise different error types"
    if not _forward[E](guard, a, b, c):
        return Guarded[O]()
    return Guarded[O](_forward[E](clause, a, b, c))
