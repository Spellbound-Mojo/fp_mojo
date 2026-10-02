"""Canonical concatenation monoids; user monoids implement the same protocol."""
from .protocols import Monoid


struct StringMonoid(Monoid):
    """String concatenation, with the empty string as identity."""
    comptime Value = String

    @staticmethod
    def empty() -> Self.Value:
        """The empty string.

        Returns:
            An empty `String`.
        """
        return String()

    @staticmethod
    def combine(var left: Self.Value, var right: Self.Value) -> Self.Value:
        """Append `right` to `left`.

        Args:
            left: The first string, consumed.
            right: The second string, consumed.

        Returns:
            `left + right`.
        """
        left += right
        return left^


struct ListMonoid[T: Movable & Deinitable](Monoid):
    """List concatenation, with the empty list as identity; elements are moved, never copied.

    Parameters:
        T: The element type.
    """
    comptime Value = List[Self.T]

    @staticmethod
    def empty() -> Self.Value:
        """The empty list.

        Returns:
            An empty `List`.
        """
        return List[Self.T]()

    @staticmethod
    def combine(var left: Self.Value, var right: Self.Value) -> Self.Value:
        """Append the elements of `right` to `left`, moving them.

        Args:
            left: The first list, consumed.
            right: The second list, consumed.

        Returns:
            The elements of `left`, then those of `right`.
        """
        left.extend(right^)
        return left^
