"""Positional partial application of native functions.

`partial(f, a, b)` stores `f` with copies of `a` and `b`; calling the result with
the remaining arguments calls `f(a, b, ...)`. The target is a plain function (no
captures). Bound parameters may be read or owned; the remaining parameters are
read, and their arguments are borrowed. Keyword binding, reordering, owned
remaining parameters and capturing targets are written as native closures.
"""
from std.builtin.rebind import rebind, downcast
from fp.callables.protocols import Thunk, Unary, Binary


comptime _Bound = Copyable & Deinitable
comptime _Rest = AnyType

# Mojo 1.1 cannot combine stored values with a forwarded argument pack in one
# call, and a stored function cannot be re-typed to take more leading
# parameters. Each bound count therefore spells its own native signature: the
# bound values as separate owned parameters, which read parameters also accept,
# then the remaining arguments as a read pack. An owned pack would admit owned
# remaining parameters, but Mojo 1.1 hands a read parameter converted from an
# owned pack a dangling value when its type is not ImplicitlyCopyable. A
# pack-typed function is not interchangeable with a fixed-arity one (different
# calling conventions), so only these shapes are used.
comptime _Fn0[R: Movable & Deinitable, E: Movable & Deinitable, Bs: TypeList[Trait=_Bound, ...], Rs: TypeList[Trait=_Rest, ...]] = def(
    *args: *Rs) raises E thin -> R
comptime _Fn1[R: Movable & Deinitable, E: Movable & Deinitable, Bs: TypeList[Trait=_Bound, ...], Rs: TypeList[Trait=_Rest, ...]] = def(
    var a0: Bs[0], *args: *Rs) raises E thin -> R
comptime _Fn2[R: Movable & Deinitable, E: Movable & Deinitable, Bs: TypeList[Trait=_Bound, ...], Rs: TypeList[Trait=_Rest, ...]] = def(
    var a0: Bs[0], var a1: Bs[1], *args: *Rs) raises E thin -> R
comptime _Fn3[R: Movable & Deinitable, E: Movable & Deinitable, Bs: TypeList[Trait=_Bound, ...], Rs: TypeList[Trait=_Rest, ...]] = def(
    var a0: Bs[0], var a1: Bs[1], var a2: Bs[2], *args: *Rs) raises E thin -> R
comptime _Fn4[R: Movable & Deinitable, E: Movable & Deinitable, Bs: TypeList[Trait=_Bound, ...], Rs: TypeList[Trait=_Rest, ...]] = def(
    var a0: Bs[0], var a1: Bs[1], var a2: Bs[2], var a3: Bs[3], *args: *Rs) raises E thin -> R
comptime _Fn5[R: Movable & Deinitable, E: Movable & Deinitable, Bs: TypeList[Trait=_Bound, ...], Rs: TypeList[Trait=_Rest, ...]] = def(
    var a0: Bs[0], var a1: Bs[1], var a2: Bs[2], var a3: Bs[3], var a4: Bs[4], *args: *Rs) raises E thin -> R
comptime _Fn6[R: Movable & Deinitable, E: Movable & Deinitable, Bs: TypeList[Trait=_Bound, ...], Rs: TypeList[Trait=_Rest, ...]] = def(
    var a0: Bs[0], var a1: Bs[1], var a2: Bs[2], var a3: Bs[3], var a4: Bs[4], var a5: Bs[5],
    *args: *Rs) raises E thin -> R
comptime _Fn7[R: Movable & Deinitable, E: Movable & Deinitable, Bs: TypeList[Trait=_Bound, ...], Rs: TypeList[Trait=_Rest, ...]] = def(
    var a0: Bs[0], var a1: Bs[1], var a2: Bs[2], var a3: Bs[3], var a4: Bs[4], var a5: Bs[5], var a6: Bs[6],
    *args: *Rs) raises E thin -> R
comptime _Fn8[R: Movable & Deinitable, E: Movable & Deinitable, Bs: TypeList[Trait=_Bound, ...], Rs: TypeList[Trait=_Rest, ...]] = def(
    var a0: Bs[0], var a1: Bs[1], var a2: Bs[2], var a3: Bs[3], var a4: Bs[4], var a5: Bs[5], var a6: Bs[6],
    var a7: Bs[7], *args: *Rs) raises E thin -> R
comptime _Fn[R: Movable & Deinitable, E: Movable & Deinitable, Bs: TypeList[Trait=_Bound, ...], Rs: TypeList[Trait=_Rest, ...]] = (
    _Fn0[R, E, Bs, Rs] if Bs.length == 0 else _Fn1[R, E, Bs, Rs] if Bs.length == 1 else
    _Fn2[R, E, Bs, Rs] if Bs.length == 2 else _Fn3[R, E, Bs, Rs] if Bs.length == 3 else
    _Fn4[R, E, Bs, Rs] if Bs.length == 4 else _Fn5[R, E, Bs, Rs] if Bs.length == 5 else
    _Fn6[R, E, Bs, Rs] if Bs.length == 6 else _Fn7[R, E, Bs, Rs] if Bs.length == 7 else _Fn8[R, E, Bs, Rs]
)


@fieldwise_init
struct Partial[R: Movable & Deinitable, E: Movable & Deinitable,
               Bs: TypeList[Trait=_Bound, ...], Rs: TypeList[Trait=_Rest, ...]](
    Copyable, Thunk where Rs.length == 0, Unary where Rs.length == 1, Binary where Rs.length == 2
):
    """A plain function with copies of its leading arguments, returned by `partial`.

    Call it with the remaining arguments, which are borrowed. Each call passes
    the function a fresh copy of every bound argument, so the stored values are
    never consumed or changed. With 0, 1 or 2 remaining arguments it is also a
    `Thunk`, `Unary` or `Binary`, which library higher-order functions accept.

    Parameters:
        R: The function's result type.
        E: The function's error type, `Never` for a pure function.
        Bs: The bound argument types.
        Rs: The remaining parameter types.
    """
    comptime Arg = downcast[Self.Rs[0], Movable & Deinitable]
    comptime First = downcast[Self.Rs[0], Movable & Deinitable]
    comptime Second = downcast[Self.Rs[1], Movable & Deinitable]
    comptime Out = Self.R
    comptime Error = Self.E
    var function: _Fn[Self.R, Self.E, Self.Bs, Self.Rs]
    """The stored function."""
    var bound: Tuple[*Self.Bs]
    """The bound arguments."""

    def __call__(self, *rest: *Self.Rs) raises Self.E -> Self.R:
        """Call the function with the bound arguments followed by `rest`.

        Args:
            rest: The remaining arguments, borrowed.

        Returns:
            The function's result.

        Raises:
            The function's error, unchanged.
        """
        return self._call(*rest)

    def call(self) raises Self.E -> Self.R:
        """`Thunk` view: call the function when no arguments remain."""
        return self._call()

    def call(self, var arg: Self.Arg) raises Self.E -> Self.R:
        """`Unary` view: call the function when one argument remains.

        Args:
            arg: The remaining argument.

        Returns:
            The function's result.

        Raises:
            The function's error, unchanged.
        """
        return self._call(arg)

    def call(self, var first: Self.First, var second: Self.Second) raises Self.E -> Self.R:
        """`Binary` view: call the function when two arguments remain."""
        return self._call(first, second)

    def _call[Pack: TypeList[Trait=_Rest, ...], //](self, *rest: *Pack) raises Self.E -> Self.R:
        # The one native call. Pack is Rs for every caller above; rebinding the
        # stored function to the same pack-typed signature changes nothing.
        comptime n = Self.Bs.length
        ref b = self.bound
        comptime if n == 0:
            return rebind[_Fn0[Self.R, Self.E, Self.Bs, Pack]](self.function)(*rest)
        elif n == 1:
            return rebind[_Fn1[Self.R, Self.E, Self.Bs, Pack]](self.function)(b[0].copy(), *rest)
        elif n == 2:
            return rebind[_Fn2[Self.R, Self.E, Self.Bs, Pack]](self.function)(b[0].copy(), b[1].copy(), *rest)
        elif n == 3:
            return rebind[_Fn3[Self.R, Self.E, Self.Bs, Pack]](self.function)(
                b[0].copy(), b[1].copy(), b[2].copy(), *rest)
        elif n == 4:
            return rebind[_Fn4[Self.R, Self.E, Self.Bs, Pack]](self.function)(
                b[0].copy(), b[1].copy(), b[2].copy(), b[3].copy(), *rest)
        elif n == 5:
            return rebind[_Fn5[Self.R, Self.E, Self.Bs, Pack]](self.function)(
                b[0].copy(), b[1].copy(), b[2].copy(), b[3].copy(), b[4].copy(), *rest)
        elif n == 6:
            return rebind[_Fn6[Self.R, Self.E, Self.Bs, Pack]](self.function)(
                b[0].copy(), b[1].copy(), b[2].copy(), b[3].copy(), b[4].copy(), b[5].copy(), *rest)
        elif n == 7:
            return rebind[_Fn7[Self.R, Self.E, Self.Bs, Pack]](self.function)(
                b[0].copy(), b[1].copy(), b[2].copy(), b[3].copy(), b[4].copy(), b[5].copy(), b[6].copy(), *rest)
        else:
            comptime assert n == 8, "partial: at most 8 bound arguments"
            return rebind[_Fn8[Self.R, Self.E, Self.Bs, Pack]](self.function)(
                b[0].copy(), b[1].copy(), b[2].copy(), b[3].copy(), b[4].copy(), b[5].copy(), b[6].copy(),
                b[7].copy(), *rest)


# One overload per bound count (see above). Each copies its bound arguments; the
# caller's values stay valid. The target converts to the spelled signature at
# this call, where its concrete type is known.
def partial[R: Movable & Deinitable, E: Movable & Deinitable, Rs: TypeList[Trait=_Rest, ...], //](
    function: def(*args: *Rs) raises E thin -> R
) -> Partial[R, E, TypeList.of[Trait=_Bound](), Rs]:
    """Store a native function without binding arguments."""
    return {function, Tuple()}


def partial[A0: _Bound, R: Movable & Deinitable, E: Movable & Deinitable, Rs: TypeList[Trait=_Rest, ...], //](
    function: def(var a0: A0, *args: *Rs) raises E thin -> R, a0: A0
) -> Partial[R, E, TypeList.of[Trait=_Bound, A0](), Rs]:
    """Bind a plain function's first argument; call the result with the rest.

    `partial(f, a)(b, c)` calls `f(a, b, c)`. The overloads bind zero to eight
    leading arguments, as in `partial(f, a, b)`. Construction copies each bound
    argument once and never calls `f`; every call passes `f` fresh copies, and
    the remaining arguments are borrowed. The result keeps `f`'s error type.

    Limitations:
        `f` must be a plain function (no captures) whose remaining parameters
        are read, not owned or `mut`; bound values must be `Copyable`; and a
        `Partial` cannot be the target of another `partial`. Keyword binding,
        reordering and the other cases are written as a closure.

    Parameters:
        A0: The bound argument's type; it must be `Copyable`.
        R: The function's result type.
        E: The function's error type, `Never` for a pure function.
        Rs: The types of the remaining parameters.

    Args:
        function: The plain function.
        a0: The value to bind, copied.

    Returns:
        A `Partial` that calls `function(a0, rest...)`.
    """
    return {function, Tuple(a0.copy())}


def partial[A0: _Bound, A1: _Bound, R: Movable & Deinitable, E: Movable & Deinitable,
            Rs: TypeList[Trait=_Rest, ...], //](
    function: def(var a0: A0, var a1: A1, *args: *Rs) raises E thin -> R, a0: A0, a1: A1
) -> Partial[R, E, TypeList.of[Trait=_Bound, A0, A1](), Rs]:
    """Bind the first two arguments."""
    return {function, Tuple(a0.copy(), a1.copy())}


def partial[A0: _Bound, A1: _Bound, A2: _Bound, R: Movable & Deinitable, E: Movable & Deinitable,
            Rs: TypeList[Trait=_Rest, ...], //](
    function: def(var a0: A0, var a1: A1, var a2: A2, *args: *Rs) raises E thin -> R,
    a0: A0, a1: A1, a2: A2
) -> Partial[R, E, TypeList.of[Trait=_Bound, A0, A1, A2](), Rs]:
    """Bind the first three arguments."""
    return {function, Tuple(a0.copy(), a1.copy(), a2.copy())}


def partial[A0: _Bound, A1: _Bound, A2: _Bound, A3: _Bound, R: Movable & Deinitable, E: Movable & Deinitable,
            Rs: TypeList[Trait=_Rest, ...], //](
    function: def(var a0: A0, var a1: A1, var a2: A2, var a3: A3, *args: *Rs) raises E thin -> R,
    a0: A0, a1: A1, a2: A2, a3: A3
) -> Partial[R, E, TypeList.of[Trait=_Bound, A0, A1, A2, A3](), Rs]:
    """Bind the first four arguments."""
    return {function, Tuple(a0.copy(), a1.copy(), a2.copy(), a3.copy())}


def partial[A0: _Bound, A1: _Bound, A2: _Bound, A3: _Bound, A4: _Bound,
            R: Movable & Deinitable, E: Movable & Deinitable, Rs: TypeList[Trait=_Rest, ...], //](
    function: def(var a0: A0, var a1: A1, var a2: A2, var a3: A3, var a4: A4, *args: *Rs) raises E thin -> R,
    a0: A0, a1: A1, a2: A2, a3: A3, a4: A4
) -> Partial[R, E, TypeList.of[Trait=_Bound, A0, A1, A2, A3, A4](), Rs]:
    """Bind the first five arguments."""
    return {function, Tuple(a0.copy(), a1.copy(), a2.copy(), a3.copy(), a4.copy())}


def partial[A0: _Bound, A1: _Bound, A2: _Bound, A3: _Bound, A4: _Bound, A5: _Bound,
            R: Movable & Deinitable, E: Movable & Deinitable, Rs: TypeList[Trait=_Rest, ...], //](
    function: def(var a0: A0, var a1: A1, var a2: A2, var a3: A3, var a4: A4, var a5: A5,
                  *args: *Rs) raises E thin -> R,
    a0: A0, a1: A1, a2: A2, a3: A3, a4: A4, a5: A5
) -> Partial[R, E, TypeList.of[Trait=_Bound, A0, A1, A2, A3, A4, A5](), Rs]:
    """Bind the first six arguments."""
    return {function, Tuple(a0.copy(), a1.copy(), a2.copy(), a3.copy(), a4.copy(), a5.copy())}


def partial[A0: _Bound, A1: _Bound, A2: _Bound, A3: _Bound, A4: _Bound, A5: _Bound, A6: _Bound,
            R: Movable & Deinitable, E: Movable & Deinitable, Rs: TypeList[Trait=_Rest, ...], //](
    function: def(var a0: A0, var a1: A1, var a2: A2, var a3: A3, var a4: A4, var a5: A5, var a6: A6,
                  *args: *Rs) raises E thin -> R,
    a0: A0, a1: A1, a2: A2, a3: A3, a4: A4, a5: A5, a6: A6
) -> Partial[R, E, TypeList.of[Trait=_Bound, A0, A1, A2, A3, A4, A5, A6](), Rs]:
    """Bind the first seven arguments."""
    return {function, Tuple(a0.copy(), a1.copy(), a2.copy(), a3.copy(), a4.copy(), a5.copy(), a6.copy())}


def partial[A0: _Bound, A1: _Bound, A2: _Bound, A3: _Bound, A4: _Bound, A5: _Bound, A6: _Bound, A7: _Bound,
            R: Movable & Deinitable, E: Movable & Deinitable, Rs: TypeList[Trait=_Rest, ...], //](
    function: def(var a0: A0, var a1: A1, var a2: A2, var a3: A3, var a4: A4, var a5: A5, var a6: A6, var a7: A7,
                  *args: *Rs) raises E thin -> R,
    a0: A0, a1: A1, a2: A2, a3: A3, a4: A4, a5: A5, a6: A6, a7: A7
) -> Partial[R, E, TypeList.of[Trait=_Bound, A0, A1, A2, A3, A4, A5, A6, A7](), Rs]:
    """Bind the first eight arguments."""
    return {function, Tuple(a0.copy(), a1.copy(), a2.copy(), a3.copy(), a4.copy(), a5.copy(), a6.copy(), a7.copy())}
