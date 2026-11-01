"""Inclusive-or values, stored by the existing inline Choice machinery."""
from fp.adt.data import Cases, Choice, Data, Value
from fp.callables.products import _take_pair
from std.memory import MaybeUninit


@fieldwise_init
struct Left[E: Movable & Deinitable](Movable, Copyable where conforms_to(E, Copyable)):
    """Diagnostics without a value in an Ior.

    Parameters:
        E: The diagnostic type, including its origins.
    """
    var value: Self.E
    """The diagnostics."""

    def into_payload(deinit self) -> Self.E:
        """Consume Left and move out its diagnostics.

        Returns:
            The diagnostic value, without copying it.
        """
        return self.value^

    def _parts[A: Movable & Deinitable](deinit self) -> _IorParts[Self.E, A]:
        return _IorParts(Optional(self^.into_payload()), Optional[A]())


@fieldwise_init
struct Right[A: Movable & Deinitable](Movable, Copyable where conforms_to(A, Copyable)):
    """A value without diagnostics in an Ior.

    Parameters:
        A: The value type, including its origins.
    """
    var value: Self.A
    """The value."""

    def into_payload(deinit self) -> Self.A:
        """Consume Right and move out its value.

        Returns:
            The payload, without copying it.
        """
        return self.value^

    def _parts[E: Movable & Deinitable](deinit self) -> _IorParts[E, Self.A]:
        return _IorParts(Optional[E](), Optional(self^.into_payload()))


@fieldwise_init
struct Both[E: Movable & Deinitable, A: Movable & Deinitable](
    Movable, Copyable where conforms_to(E, Copyable) and conforms_to(A, Copyable)
):
    """Diagnostics alongside a value: success with warnings when E holds issues.

    Parameters:
        E: The diagnostic type, including its origins.
        A: The value type, including its origins.
    """
    var left: Self.E
    """The diagnostics."""
    var right: Self.A
    """The value."""

    def into_payload(deinit self) -> Tuple[Self.E, Self.A]:
        """Consume Both and move its diagnostics and value into a native pair.

        Returns:
            A Tuple of diagnostics followed by the value; neither is copied.
        """
        return (self.left^, self.right^)

    def _parts(deinit self) -> _IorParts[Self.E, Self.A]:
        var diagnostics = MaybeUninit[Self.E]()
        var payload = MaybeUninit[Self.A]()
        _take_pair(self^.into_payload(), diagnostics, payload)
        return _IorParts(Optional(diagnostics^.unsafe_assume_init()), Optional(payload^.unsafe_assume_init()))


trait _IorData(Data):
    comptime Diagnostics: Movable & Deinitable
    comptime Payload: Movable & Deinitable


struct _IorCases[E: Movable & Deinitable, A: Movable & Deinitable](_IorData):
    comptime Diagnostics = Self.E
    comptime Payload = Self.A
    comptime Layer[R: Value] = Cases[Left[Self.E], Right[Self.A], Both[Self.E, Self.A]]


comptime Ior[E: Movable & Deinitable, A: Movable & Deinitable] = Choice[_IorCases[E, A]]
"""Left(E), Right(A), or Both(E, A), stored in place in a native Variant.

Constructors convert implicitly when the Ior type is known. Inspect with
`isa`, borrow with constructor indexing, consume with `unwrap`, or use the
existing exhaustive `fp.match`. Copying requires both payload types to be
Copyable; moving and matching support move-only payloads and native origins.
The carrier adds constant tag work and no heap allocation. It never raises
stored diagnostics. Its algebra policies are selected explicitly in
`fp.algebra`; the carrier imports no algebra or effect layer.

Parameters:
    E: The diagnostic type, conventionally on the left.
    A: The value type, conventionally on the right.
"""


@fieldwise_init
struct _IorParts[E: Movable & Deinitable, A: Movable & Deinitable](Movable):
    # Named owned slots avoid Tuple's borrowing-only indexed access.
    var diagnostics: Optional[Self.E]
    var payload: Optional[Self.A]

    def split(deinit self, mut diagnostics: Optional[Self.E], mut payload: Optional[Self.A]):
        diagnostics = self.diagnostics^
        payload = self.payload^


def _ior_parts[E: Movable & Deinitable, A: Movable & Deinitable](var source: Ior[E, A]
) -> _IorParts[E, A]:
    """Move the active fields out once; at least one returned slot is present."""
    if source.isa[Left[E]]():
        return source^.unwrap[Left[E]]()._parts[A]()
    if source.isa[Right[A]]():
        return source^.unwrap[Right[A]]()._parts[E]()
    return source^.unwrap[Both[E, A]]()._parts()


def _ior_from_parts[E: Movable & Deinitable, A: Movable & Deinitable](
    var diagnostics: Optional[E], var value: Optional[A]
) -> Ior[E, A]:
    """Restore the tag from owned slots; callers preserve at least one field."""
    if value:
        var payload = value.unsafe_take()
        if diagnostics:
            return Both(diagnostics.unsafe_take(), payload^)
        return Right(payload^)
    debug_assert(Bool(diagnostics), "Ior requires diagnostics or a value")
    return Left(diagnostics.unsafe_take())
