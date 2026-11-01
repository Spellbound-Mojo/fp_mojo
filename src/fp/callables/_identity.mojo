"""Owned identity shared by callable, algebra, data and iteration layers."""
from .protocols import Unary


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
        return self.call(arg^)
