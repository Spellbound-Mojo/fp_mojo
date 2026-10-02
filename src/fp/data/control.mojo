"""Early termination values: `Break` or `Continue`, stored in place."""

from fp.adt.data import Cases, Choice, Data, Value


@fieldwise_init
struct Break[T: Movable & Deinitable](Movable, Copyable where conforms_to(T, Copyable)):
    """Stop a `fold_until` with a value.

    Parameters:
        T: The value's type.
    """
    var value: Self.T
    """The value."""

    def into_payload(deinit self) -> Self.T:
        """Consume the constructor and return its value.

        Returns:
            The value, moved out.
        """
        return self.value^


@fieldwise_init
struct Continue[T: Movable & Deinitable](Movable, Copyable where conforms_to(T, Copyable)):
    """Continue a `fold_until` with the next accumulator.

    It stays distinct from `Break` even when the two payload types are equal.

    Parameters:
        T: The accumulator's type.
    """
    var value: Self.T
    """The accumulator."""

    def into_payload(deinit self) -> Self.T:
        """Consume the constructor and return its value.

        Returns:
            The value, moved out.
        """
        return self.value^


struct _ControlCases[B: Movable & Deinitable, C: Movable & Deinitable](Data):
    """ControlFlow's data type: its two constructors, neither recursive."""
    comptime Layer[R: Value] = Cases[Break[Self.B], Continue[Self.C]]


comptime ControlFlow[B: Movable & Deinitable, C: Movable & Deinitable] = Choice[_ControlCases[B, C]]
"""`Break[B]` or `Continue[C]`, stored in place: the outcome of a `fold_until` step.

A `Choice` of the two constructors: a step returns `Break(value)` or
`Continue(value)`, and the outcome is read with `isa`, indexing, the consuming
`unwrap`, or `fp.match`.

Parameters:
    B: The type a fold stops with.
    C: The accumulator type.
"""
