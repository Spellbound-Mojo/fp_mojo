"""A non-empty sequence with native List storage and consuming iteration."""
from std.iter import IterableOwned


struct NonEmptyList[T: Movable & Deinitable](
    Movable, Copyable where conforms_to(T, Copyable), IterableOwned, Sized
):
    """A native List whose supported constructors require at least one element.

    Construct from a first value and an optional tail, or use `from_list` to
    check an existing List. The latter and `into_list` transfer the existing
    buffer without copying elements. There is no empty constructor or removal
    operation; filter through NonEmptyListFamily returns a possibly empty List.
    Copying requires Copyable elements. Consuming iteration uses List's own
    iterator, including destruction of an unvisited suffix.

    Parameters:
        T: The element type, including any borrowed origins.
    """
    var _values: List[Self.T]
    comptime IteratorOwnedType = List[Self.T].IteratorOwnedType

    def __init__(out self, var first: Self.T):
        """Construct a singleton without creating a second origin-bearing input.

        Args:
            first: The sole element, moved in, including any mutable borrowed origin.
        """
        self._values = List[Self.T]()
        self._values.append(first^)

    def __init__(out self, var first: Self.T, var rest: List[Self.T]):
        """Construct a first element followed by the supplied tail.

        Args:
            first: The first element, moved in.
            rest: The remaining elements, consumed in order.
        """
        self = Self(first^)
        self._values.extend(rest^)

    def __init__(out self, *, var values: List[Self.T]) raises:
        """Check and consume a native List, retaining its allocation.

        The keyword values distinguishes checking a List from storing one as
        the sole payload of a NonEmptyList[List[T]].

        Args:
            values: The source List, consumed even when empty.

        Raises:
            Error if the List is empty. Use from_list for an Optional instead.
        """
        if len(values) == 0:
            raise Error("NonEmptyList requires at least one element")
        self._values = values^

    @staticmethod
    def from_list(var values: List[Self.T]) -> Optional[Self]:
        """Check whether a consumed List contains a first element.

        Args:
            values: The source List; its elements and buffer are moved.

        Returns:
            A present NonEmptyList, or None for an empty List.
        """
        try:
            return Optional(Self(values=values^))
        except:
            return None

    def first(ref self) -> ref[self._values[0]] Self.T:
        """Borrow the guaranteed first element with the native List origin.

        Returns:
            A reference to the first element; no payload is copied.
        """
        return self._values[0]

    def __len__(self) -> Int:
        """Return the number of elements, always at least one.

        Returns:
            The native List length.
        """
        return len(self._values)

    def into_list(deinit self) -> List[Self.T]:
        """Transfer the buffer into an ordinary List in constant time.

        Returns:
            The native List, with the same order and element origins.
        """
        return self._values^

    def __iter__(var self) -> Self.IteratorOwnedType:
        """Consume the collection into its native List iterator.

        Returns:
            An iterator moving each element once, in order.
        """
        return iter(self^.into_list())
