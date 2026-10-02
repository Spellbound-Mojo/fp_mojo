"""Functional while and counted loops with exact native carry types."""
from std.builtin.rebind import rebind_var
from fp._internal.errors import _ErrorCompatible, _CommonError
from fp.callables.protocols import BorrowCallable, Unary, Binary
from fp.iteration._callbacks import _predicate_plain, _predicate_raising, _predicate_callable, _binary_plain, _binary_raising
from ._loops import _while, _indexed, _for_step


def _unary_plain[A: Movable & Deinitable, F: def(var A) -> A](function: F, var value: A) capturing -> A:
    return function(value^)


def _unary_raising[A: Movable & Deinitable, E: Movable & Deinitable, F: def(var A) raises E -> A](
    function: F, var value: A
) raises E capturing -> A:
    return function(value^)


def _unary_fixed[A: Movable & Deinitable, F: Unary](function: F, var value: A) raises F.Error capturing -> A:
    comptime assert F.Arg == A and F.Out == A, "while_loop: the body must take and return the carry"
    return rebind_var[A](function.call(rebind_var[F.Arg](value^)))


def _index_fixed[A: Movable & Deinitable, F: Binary](var index: Int, var value: A, function: F
) raises F.Error capturing -> A:
    comptime assert F.First == Int and F.Second == A and F.Out == A, "fori_loop: the body must take (Int, carry) and return the carry"
    return rebind_var[A](function.call(rebind_var[F.First](index), rebind_var[F.Second](value^)))


def while_loop[A: Movable & Deinitable, P: BorrowCallable, F: Unary](
    cond_fun: P, body_fun: F, var init_val: A
) raises _CommonError[P.Failure, F.Error] -> A where P.Payload == A and P.Result == Bool and F.Arg == A and F.Out == A and _ErrorCompatible[_CommonError[P.Failure, F.Error], P.Failure] and _ErrorCompatible[_CommonError[P.Failure, F.Error], F.Error]:
    """Loop with a `BorrowCallable` predicate and a library `Unary` body."""
    comptime E = _CommonError[P.Failure, F.Error]
    return _while[A, P, F, P.Failure, F.Error, _predicate_callable[A, P], _unary_fixed[A, F], E](
        cond_fun, body_fun, init_val^)


# Native pure/raising signatures have distinct conformance on Mojo 1.1.
# Only admission varies; all combinations enter the same loop kernel.


def while_loop[A: Movable & Deinitable,
               //,
               P: def(A) -> Bool,
               F: def(var A) -> A](
    cond_fun: P, body_fun: F, var init_val: A
) raises _CommonError[Never, Never] -> A where _ErrorCompatible[_CommonError[Never, Never], Never]:
    """Repeat `body_fun` while `cond_fun` holds for the carry, and return the carry.

    The predicate borrows the carry before each iteration. When it returns
    `False` the current carry is returned; otherwise the carry moves into the
    body, which returns the next one of exactly the same type. Nothing copies
    the carry.

    Parameters:
        A: The carry type: any value, including a move-only owner.
        P: The predicate's type: a plain function or a closure.
        F: The body's type: a plain function or a closure.

    Args:
        cond_fun: The predicate, borrowed.
        body_fun: The body, borrowed.
        init_val: The first carry, consumed.

    Returns:
        The carry for which the predicate first returned `False`.

    Raises:
        Nothing: `Never` for a pure predicate and body. The raising overloads
        raise the predicate's or the body's error, which stops the loop at once.
    """
    return _while[A, P, F, Never, Never, _predicate_plain[A, P], _unary_plain[A, F], _CommonError[Never, Never]](cond_fun, body_fun, init_val^)


def while_loop[A: Movable & Deinitable,
               BE: Movable & Deinitable,
               //,
               P: def(A) -> Bool,
               F: def(var A) raises BE -> A](
    cond_fun: P, body_fun: F, var init_val: A
) raises _CommonError[Never, BE] -> A where _ErrorCompatible[_CommonError[Never, BE], BE]:
    """Loop with a raising body; its error stops the loop at once."""
    return _while[A, P, F, Never, BE, _predicate_plain[A, P], _unary_raising[A, BE, F], _CommonError[Never, BE]](cond_fun, body_fun, init_val^)


def while_loop[A: Movable & Deinitable,
               PE: Movable & Deinitable,
               //,
               P: def(A) raises PE -> Bool,
               F: def(var A) -> A](
    cond_fun: P, body_fun: F, var init_val: A
) raises _CommonError[PE, Never] -> A where _ErrorCompatible[_CommonError[PE, Never], PE] and _ErrorCompatible[_CommonError[PE, Never], Never]:
    """Loop with a raising predicate; its error stops the loop at once."""
    return _while[A, P, F, PE, Never, _predicate_raising[A, PE, P], _unary_plain[A, F], _CommonError[PE, Never]](cond_fun, body_fun, init_val^)


def while_loop[A: Movable & Deinitable,
               PE: Movable & Deinitable,
               BE: Movable & Deinitable,
               //,
               P: def(A) raises PE -> Bool,
               F: def(var A) raises BE -> A](
    cond_fun: P, body_fun: F, var init_val: A
) raises _CommonError[PE, BE] -> A where _ErrorCompatible[_CommonError[PE, BE], PE] and _ErrorCompatible[_CommonError[PE, BE], BE]:
    """Loop with a raising predicate and body, which raise one error type or one of them nothing."""
    return _while[A, P, F, PE, BE, _predicate_raising[A, PE, P], _unary_raising[A, BE, F], _CommonError[PE, BE]](cond_fun, body_fun, init_val^)


def fori_loop[A: Movable & Deinitable,
              F: def(var Int, var A) -> A,
              //,
              unroll: Int = 1](
    lower: Int, upper: Int, body_fun: F, var init_val: A
) raises Never -> A:
    """Call `body_fun(index, carry)` for each index in `[lower, upper)`, in ascending order.

    Equal or reversed bounds return `init_val` without a call; negative bounds
    are valid. Static bounds are written `fori_loop[lower, upper](body, carry)`.

    Parameters:
        A: The carry type: any value, including a move-only owner.
        F: The body's type: a plain function or a closure taking the index and the carry.
        unroll: How many steps each rolled iteration expands: `1`, the default,
            keeps a rolled loop, and `0` fully expands a loop with static bounds.
            Call order and error behavior do not change.

    Args:
        lower: The first index.
        upper: The bound, excluded.
        body_fun: The body, borrowed.
        init_val: The first carry, consumed.

    Returns:
        The carry after the last call.

    Raises:
        Nothing: `Never` for a pure body. The raising overloads raise the body's
        error, which stops the loop at once.
    """
    return _indexed[A, Pointer[F, origin_of(body_fun)], Never,
        _for_step[A, F, Never, origin_of(body_fun), _binary_plain[Int, A, A, F]], unroll](
        lower, upper, Pointer(to=body_fun), init_val^)


def fori_loop[A: Movable & Deinitable,
              E: Movable & Deinitable,
              F: def(var Int, var A) raises E -> A,
              //,
              unroll: Int = 1](
    lower: Int, upper: Int, body_fun: F, var init_val: A
) raises E -> A:
    """Counted loop with a raising body; its error stops the loop at once."""
    return _indexed[A, Pointer[F, origin_of(body_fun)], E,
        _for_step[A, F, E, origin_of(body_fun), _binary_raising[Int, A, A, E, F]], unroll](
        lower, upper, Pointer(to=body_fun), init_val^)


def fori_loop[A: Movable & Deinitable,
              F: Binary,
              //,
              unroll: Int = 1](
    lower: Int, upper: Int, body_fun: F, var init_val: A
) raises F.Error -> A where F.First == Int and F.Second == A and F.Out == A:
    """Counted loop with a library `Binary` body taking `(Int, carry)`."""
    return _indexed[A, Pointer[F, origin_of(body_fun)], F.Error,
        _for_step[A, F, F.Error, origin_of(body_fun), _index_fixed[A, F]], unroll](
        lower, upper, Pointer(to=body_fun), init_val^)


def fori_loop[A: Movable & Deinitable,
              F: def(var Int, var A) -> A,
              //,
              lower: Int,
              upper: Int,
              unroll: Int = 1](
    body_fun: F, var init_val: A
) raises Never -> A:
    """Counted loop with static bounds, which `unroll=0` can expand fully."""
    return _indexed[A, Pointer[F, origin_of(body_fun)], Never,
        _for_step[A, F, Never, origin_of(body_fun), _binary_plain[Int, A, A, F]], unroll, True, lower, upper](
        lower, upper, Pointer(to=body_fun), init_val^)


def fori_loop[A: Movable & Deinitable,
              E: Movable & Deinitable,
              F: def(var Int, var A) raises E -> A,
              //,
              lower: Int,
              upper: Int,
              unroll: Int = 1](
    body_fun: F, var init_val: A
) raises E -> A:
    """Counted loop with static bounds and a raising body."""
    return _indexed[A, Pointer[F, origin_of(body_fun)], E,
        _for_step[A, F, E, origin_of(body_fun), _binary_raising[Int, A, A, E, F]], unroll, True, lower, upper](
        lower, upper, Pointer(to=body_fun), init_val^)


def fori_loop[A: Movable & Deinitable,
              F: Binary,
              //,
              lower: Int,
              upper: Int,
              unroll: Int = 1](
    body_fun: F, var init_val: A
) raises F.Error -> A where F.First == Int and F.Second == A and F.Out == A:
    """Counted loop with static bounds and a library `Binary` body."""
    return _indexed[A, Pointer[F, origin_of(body_fun)], F.Error,
        _for_step[A, F, F.Error, origin_of(body_fun), _index_fixed[A, F]], unroll, True, lower, upper](
        lower, upper, Pointer(to=body_fun), init_val^)
