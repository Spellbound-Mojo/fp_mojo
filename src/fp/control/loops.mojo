"""Functional while and counted loops with exact native carry types."""
from std.builtin.rebind import rebind_var
from fp._internal.errors import _ErrorCompatible, _CommonError, _CommonErrorCompatible
from fp.callables.protocols import BorrowCallContract, BorrowCallable, Unary, UnaryContract, Binary, BinaryContract
from fp.callables.invoke import RepeatableBorrow, RepeatableBinary, RepeatableUnary
from fp.callables._receiver import _SharedBorrowRef, _binary_repeated_as, _unary_repeated_as
from fp.iteration._callbacks import _predicate_repeated, _predicate_plain, _predicate_raising, _predicate_callable, _binary_plain, _binary_raising
from fp.callables.native import NativeBorrow
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


def _indexed_repeated[A: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, o: MutOrigin](
    var value: A, index: Int, function: Pointer[F, o]
) raises F.Error capturing -> A where RepeatableBinary[F]:
    """Use the canonical repeated receiver at the existing indexed-loop boundary."""
    comptime assert F.First == Int and F.Second == A and F.Out == A, "fori_loop_mut: the body must take (Int, carry) and return the carry"
    return rebind_var[A](_binary_repeated_as[F.Error](function[], rebind_var[F.First](index), rebind_var[F.Second](value^)))


def while_loop[A: Movable & Deinitable, P: BorrowCallable, F: Unary](
    cond_fun: P, body_fun: F, var init_val: A
) raises _CommonError[P.Failure, F.Error] -> A where P.Payload == A and P.Result == Bool and F.Arg == A and F.Out == A and _ErrorCompatible[_CommonError[P.Failure, F.Error], P.Failure] and _ErrorCompatible[_CommonError[P.Failure, F.Error], F.Error]:
    """Loop with a `BorrowCallable` predicate and a library `Unary` body."""
    comptime E = _CommonError[P.Failure, F.Error]
    return _while[A, P, F, P.Failure, F.Error, _predicate_callable[A, P], _unary_fixed[A, F], E](
        cond_fun, body_fun, init_val^)


# Native pure/raising signatures have distinct conformance on Mojo 1.1.
# Only admission varies; all combinations enter the same loop kernel.


def while_loop[A: Movable & Deinitable, R: Movable & Deinitable,
               //,
               P: def(A) -> R,
               F: def(var A) -> A](
    cond_fun: P, body_fun: F, var init_val: A
) raises _CommonError[Never, Never] -> A where R == Bool and _ErrorCompatible[_CommonError[Never, Never], Never]:
    """Repeat `body_fun` while `cond_fun` holds for the carry, and return the carry.

    The predicate borrows the carry before each iteration. When it returns
    `False` the current carry is returned; otherwise the carry moves into the
    body, which returns the next one of exactly the same type. Nothing copies
    the carry.

    Parameters:
        A: The carry type: any value, including a move-only owner.
        R: The native callback result, checked against Bool or the carry type.
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
    return _while[A, P, F, Never, Never, _predicate_plain[A, R, P], _unary_plain[A, F], _CommonError[Never, Never]](cond_fun, body_fun, init_val^)


def while_loop[A: Movable & Deinitable, R: Movable & Deinitable,
               BE: Movable & Deinitable,
               //,
               P: def(A) -> R,
               F: def(var A) raises BE -> A](
    cond_fun: P, body_fun: F, var init_val: A
) raises _CommonError[Never, BE] -> A where R == Bool and _ErrorCompatible[_CommonError[Never, BE], BE]:
    """Loop with a raising body; its error stops the loop at once."""
    return _while[A, P, F, Never, BE, _predicate_plain[A, R, P], _unary_raising[A, BE, F], _CommonError[Never, BE]](cond_fun, body_fun, init_val^)


def while_loop[A: Movable & Deinitable, R: Movable & Deinitable,
               PE: Movable & Deinitable,
               //,
               P: def(A) raises PE -> R,
               F: def(var A) -> A](
    cond_fun: P, body_fun: F, var init_val: A
) raises _CommonError[PE, Never] -> A where R == Bool and _ErrorCompatible[_CommonError[PE, Never], PE] and _ErrorCompatible[_CommonError[PE, Never], Never]:
    """Loop with a raising predicate; its error stops the loop at once."""
    return _while[A, P, F, PE, Never, _predicate_raising[A, PE, R, P], _unary_plain[A, F], _CommonError[PE, Never]](cond_fun, body_fun, init_val^)


def while_loop[A: Movable & Deinitable, R: Movable & Deinitable,
               PE: Movable & Deinitable,
               BE: Movable & Deinitable,
               //,
               P: def(A) raises PE -> R,
               F: def(var A) raises BE -> A](
    cond_fun: P, body_fun: F, var init_val: A
) raises _CommonError[PE, BE] -> A where R == Bool and _ErrorCompatible[_CommonError[PE, BE], PE] and _ErrorCompatible[_CommonError[PE, BE], BE]:
    """Loop with a raising predicate and body, which raise one error type or one of them nothing."""
    return _while[A, P, F, PE, BE, _predicate_raising[A, PE, R, P], _unary_raising[A, BE, F], _CommonError[PE, BE]](cond_fun, body_fun, init_val^)


comptime _WhileBody[A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Arg == A and F.Out == A and RepeatableUnary[F]


def _while_repeated[A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, o: MutOrigin](
    function: Pointer[F, o], var value: A
) raises F.Error capturing -> A where _WhileBody[A, F]:
    """Bridge the existing loop kernel to canonical repeated receiver dispatch."""
    return rebind_var[A](_unary_repeated_as[F.Error](function[], rebind_var[F.Arg](value^)))


def _while_mut_owned[A: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable, F: UnaryContract & Movable & Deinitable, E: Movable & Deinitable](var cond_fun: P, mut body_fun: F, var init_val: A) raises E -> A:
    """Validate both callbacks once and retain their native receiver pointers."""
    comptime assert RepeatableBorrow[P], "while loop: the predicate must have a repeatable receiver"
    comptime assert P.Payload == A, "while loop: the predicate must read the carry"
    comptime assert P.Result == Bool, "while loop: the predicate must return Bool"
    comptime assert _WhileBody[A, F], "while loop: the body must repeatedly take and return the carry"
    comptime assert _CommonErrorCompatible[P.Failure, F.Error], "while loop: incompatible errors; predicate and body errors must match or be Never"
    comptime assert E == _CommonError[P.Failure, F.Error], "while loop: incompatible errors; selected error must match the exact combined error"
    comptime assert _ErrorCompatible[E, P.Failure] and _ErrorCompatible[E, F.Error], "while loop: incompatible errors; selected error must equal each raising callback's exact error"
    return _while[A, Pointer[P, origin_of(cond_fun)], Pointer[F, origin_of(body_fun)], P.Failure, F.Error, _predicate_repeated[A, P, origin_of(cond_fun)], _while_repeated[A, F, origin_of(body_fun)], E](Pointer(to=cond_fun), Pointer(to=body_fun), init_val^)


def while_loop_mut[A: Movable & Deinitable, P: BorrowCallable, F: UnaryContract & Movable & Deinitable,
                    //, E: Movable & Deinitable = _CommonError[P.Failure, F.Error]](
    cond_fun: P, mut body_fun: F, var init_val: A
) raises E -> A:
    """Repeat a named library body with exclusive access to its receiver.

    The predicate reads the carry before each step. A false result returns
    that carry without calling the body. Each successful body call consumes
    the carry and returns the next value of exactly the same type. Mutable
    invocation wins when the body also supports shared or consuming calls.
    The body and predicate remain available afterward, including on error.

    Parameters:
        A: The carry type, including move-only values and borrowed views.
        P: A shared read-only predicate returning `Bool`.
        F: A repeatable unary body with matching input and output carry types.
        E: The exact common error, normally inferred. Generic wrappers may select it explicitly.

    Args:
        cond_fun: The predicate, borrowed for the loop.
        body_fun: A named library callback, borrowed exclusively for the loop.
        init_val: The initial carry, consumed without copying.

    Returns:
        The carry for which the predicate first returned `False`.

    Raises:
        The predicate's or body's exact error type. Their errors must match,
        including origins, or one must be `Never`. Failure stops immediately;
        receiver updates are retained and the current carry is destroyed.
    """
    return _while_mut_owned[A, _SharedBorrowRef[P, origin_of(cond_fun)], F, E](_SharedBorrowRef[P, origin_of(cond_fun)](Pointer(to=cond_fun)), body_fun, init_val^)


def while_loop_mut[A: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable, F: UnaryContract & Movable & Deinitable,
                    //, E: Movable & Deinitable = _CommonError[P.Failure, F.Error]](
    var cond_fun: P, mut body_fun: F, var init_val: A
) raises E -> A:
    """Consume a repeatable predicate and loop with a named library body.

    The predicate borrows the current carry and keeps one receiver for the
    loop. Mutable invocation wins over shared invocation for both callbacks;
    consuming-only receivers cannot repeat. A false predicate returns the
    current carry without calling the body. Each successful body call consumes
    that carry and returns its successor of exactly the same type.

    The body remains available after success or failure. Pass `mut_ref(predicate)`
    to retain the original predicate's state too; otherwise its owner is consumed.

    Parameters:
        A: The carry type, including move-only values and borrowed views.
        P: A shared or mutable borrowing predicate returning Bool.
        F: A repeatable unary body taking and returning the carry type.
        E: The exact combined error, normally inferred; generic wrappers may name it.

    Args:
        cond_fun: The predicate owner, consumed for the whole loop.
        body_fun: A named body, borrowed exclusively for the whole loop.
        init_val: The initial carry, consumed without copying.

    Returns:
        The carry for which the predicate first returned False.

    Raises:
        The predicate's or body's exact error. Their errors must match,
        including origins, or one must be Never. Failure stops immediately,
        preserves retained receiver state and destroys the current carry.
    """
    return _while_mut_owned[A, P, F, E](cond_fun^, body_fun, init_val^)



# Native admission only: captures and pointer aliases use BorrowSignature.
# Inferring a native function trait here crashes on incompatible predicates.
# Thin signatures recover the native read ABI, then enter the library overload.
def while_loop_mut[A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, R: RegisterPassable & Deinitable,
                    //, E: Movable & Deinitable = F.Error](
    cond_fun: def(A) thin -> R,
    mut body_fun: F,
    var init_val: A
) raises E -> A where not conforms_to(A, TrivialRegisterPassable) and R == Bool and _WhileBody[A, F]:
    """Loop with a native predicate and an exclusively borrowed library body.

    Parameters:
        A: The carry type, selected by the initial value.
        F: A repeatable library body with matching input and output carry types.
        R: The native result, required to be `Bool`.
        E: The exact common error, normally inferred. Generic wrappers may select it explicitly.

    Args:
        cond_fun: A plain function or stored pointer that reads the carry.
        body_fun: A named library callback, borrowed exclusively.
        init_val: The initial carry, consumed without copying.

    Returns:
        The first carry for which the predicate returns `False`.

    Raises:
        The compatible predicate/body error, stopping the loop immediately.
    """
    return while_loop_mut[E=E](NativeBorrow[A, R, Never, type_of(cond_fun), False](cond_fun), body_fun, init_val^)


def while_loop_mut[A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, B: TrivialRegisterPassable, R: RegisterPassable & Deinitable,
                    //, E: Movable & Deinitable = F.Error](
    cond_fun: def(B) thin -> R,
    mut body_fun: F,
    var init_val: A
) raises E -> A where B == A and R == Bool and _WhileBody[A, F]:
    """Loop with a native predicate and an exclusively borrowed library body.

    Parameters:
        A: The carry type, selected by the initial value.
        F: A repeatable library body with matching input and output carry types.
        B: The native register input, required to equal the carry type.
        R: The native result, required to be `Bool`.
        E: The exact common error, normally inferred. Generic wrappers may select it explicitly.

    Args:
        cond_fun: A plain function or stored pointer that reads the carry.
        body_fun: A named library callback, borrowed exclusively.
        init_val: The initial carry, consumed without copying.

    Returns:
        The first carry for which the predicate returns `False`.

    Raises:
        The compatible predicate/body error, stopping the loop immediately.
    """
    return while_loop_mut[E=E](NativeBorrow[A, R, Never, type_of(cond_fun), False](cond_fun), body_fun, init_val^)


def while_loop_mut[A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, R: RegisterPassable & Deinitable, PE: Movable & Deinitable,
                    //, E: Movable & Deinitable = _CommonError[PE, F.Error]](
    cond_fun: def(A) raises PE thin -> R,
    mut body_fun: F,
    var init_val: A
) raises E -> A where not conforms_to(A, TrivialRegisterPassable) and R == Bool and _WhileBody[A, F] and _CommonErrorCompatible[PE, F.Error]:
    """Loop with a native predicate and an exclusively borrowed library body.

    Parameters:
        A: The carry type, selected by the initial value.
        F: A repeatable library body with matching input and output carry types.
        R: The native result, required to be `Bool`.
        PE: The predicate's exact native error type.
        E: The exact common error, normally inferred. Generic wrappers may select it explicitly.

    Args:
        cond_fun: A plain function or stored pointer that reads the carry.
        body_fun: A named library callback, borrowed exclusively.
        init_val: The initial carry, consumed without copying.

    Returns:
        The first carry for which the predicate returns `False`.

    Raises:
        The compatible predicate/body error, stopping the loop immediately.
    """
    return while_loop_mut[E=E](NativeBorrow[A, R, PE, type_of(cond_fun), True](cond_fun), body_fun, init_val^)


def while_loop_mut[A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, B: TrivialRegisterPassable, R: RegisterPassable & Deinitable, PE: Movable & Deinitable,
                    //, E: Movable & Deinitable = _CommonError[PE, F.Error]](
    cond_fun: def(B) raises PE thin -> R,
    mut body_fun: F,
    var init_val: A
) raises E -> A where B == A and R == Bool and _WhileBody[A, F] and _CommonErrorCompatible[PE, F.Error]:
    """Loop with a native predicate and an exclusively borrowed library body.

    Parameters:
        A: The carry type, selected by the initial value.
        F: A repeatable library body with matching input and output carry types.
        B: The native register input, required to equal the carry type.
        R: The native result, required to be `Bool`.
        PE: The predicate's exact native error type.
        E: The exact common error, normally inferred. Generic wrappers may select it explicitly.

    Args:
        cond_fun: A plain function or stored pointer that reads the carry.
        body_fun: A named library callback, borrowed exclusively.
        init_val: The initial carry, consumed without copying.

    Returns:
        The first carry for which the predicate returns `False`.

    Raises:
        The compatible predicate/body error, stopping the loop immediately.
    """
    return while_loop_mut[E=E](NativeBorrow[A, R, PE, type_of(cond_fun), True](cond_fun), body_fun, init_val^)


def fori_loop[A: Movable & Deinitable, R: Movable & Deinitable,
              F: def(var Int, var A) -> R,
              //,
              unroll: Int = 1](
    lower: Int, upper: Int, body_fun: F, var init_val: A
) raises Never -> A where R == A:
    """Call `body_fun(index, carry)` for each index in `[lower, upper)`, in ascending order.

    Equal or reversed bounds return `init_val` without a call; negative bounds
    are valid. Static bounds are written `fori_loop[lower, upper](body, carry)`.

    Parameters:
        A: The carry type: any value, including a move-only owner.
        R: The native callback result, checked against Bool or the carry type.
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
        _for_step[A, F, Never, origin_of(body_fun), _binary_plain[Int, A, R, F, Int, A, A]], unroll](
        lower, upper, Pointer(to=body_fun), init_val^)


def fori_loop[A: Movable & Deinitable, R: Movable & Deinitable,
              E: Movable & Deinitable,
              F: def(var Int, var A) raises E -> R,
              //,
              unroll: Int = 1](
    lower: Int, upper: Int, body_fun: F, var init_val: A
) raises E -> A where R == A:
    """Counted loop with a raising body; its error stops the loop at once."""
    return _indexed[A, Pointer[F, origin_of(body_fun)], E,
        _for_step[A, F, E, origin_of(body_fun), _binary_raising[Int, A, R, E, F, Int, A, A]], unroll](
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


def fori_loop[A: Movable & Deinitable, R: Movable & Deinitable,
              F: def(var Int, var A) -> R,
              //,
              lower: Int,
              upper: Int,
              unroll: Int = 1](
    body_fun: F, var init_val: A
) raises Never -> A where R == A:
    """Counted loop with static bounds, which `unroll=0` can expand fully."""
    return _indexed[A, Pointer[F, origin_of(body_fun)], Never,
        _for_step[A, F, Never, origin_of(body_fun), _binary_plain[Int, A, R, F, Int, A, A]], unroll, True, lower, upper](
        lower, upper, Pointer(to=body_fun), init_val^)


def fori_loop[A: Movable & Deinitable, R: Movable & Deinitable,
              E: Movable & Deinitable,
              F: def(var Int, var A) raises E -> R,
              //,
              lower: Int,
              upper: Int,
              unroll: Int = 1](
    body_fun: F, var init_val: A
) raises E -> A where R == A:
    """Counted loop with static bounds and a raising body."""
    return _indexed[A, Pointer[F, origin_of(body_fun)], E,
        _for_step[A, F, E, origin_of(body_fun), _binary_raising[Int, A, R, E, F, Int, A, A]], unroll, True, lower, upper](
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


def fori_loop_mut[A: Movable & Deinitable, F: BinaryContract & Movable & Deinitable,
                  //, unroll: Int = 1](
    lower: Int, upper: Int, mut body_fun: F, var init_val: A
) raises F.Error -> A where RepeatableBinary[F] and F.First == Int and F.Second == A and F.Out == A:
    """Run a counted loop with exclusive access to a reusable library body.

    The body remains in the caller and retains its state after success or a
    raised error. Each step uses `call_repeated`: mutable invocation takes
    priority when available, otherwise a shared callback is invoked. Nothing
    copies the body or carry. Bounds and unrolling follow `fori_loop`.

    Parameters:
        A: The exact carry type, including any borrowed origins.
        F: The shared or mutable binary library callback's type.
        unroll: Steps per rolled iteration; must be positive for dynamic bounds.

    Args:
        lower: The first index.
        upper: The excluded upper bound.
        body_fun: A named callback, borrowed exclusively for this call.
        init_val: The first carry, consumed.

    Returns:
        The carry after the final step, or the initial carry for empty bounds.

    Raises:
        The body's exact error type; execution stops without rolling back state.
    """
    return _indexed[A, Pointer[F, origin_of(body_fun)], F.Error,
        _indexed_repeated[A, F, origin_of(body_fun)], unroll](
        lower, upper, Pointer(to=body_fun), init_val^)


def fori_loop_mut[A: Movable & Deinitable, F: BinaryContract & Movable & Deinitable,
                  //, lower: Int, upper: Int, unroll: Int = 1](
    mut body_fun: F, var init_val: A
) raises F.Error -> A where RepeatableBinary[F] and F.First == Int and F.Second == A and F.Out == A:
    """Run a statically bounded counted loop with exclusive callback access.

    The receiver and carry follow `fori_loop_mut` with dynamic bounds. Static
    bounds also permit `unroll=0`, which fully expands the same ordered steps.

    Parameters:
        A: The exact carry type, including any borrowed origins.
        F: The shared or mutable binary library callback's type.
        lower: The first index, known at compile time.
        upper: The excluded upper bound, known at compile time.
        unroll: Steps per rolled iteration, or zero for full static expansion.

    Args:
        body_fun: A named callback, borrowed exclusively for this call.
        init_val: The first carry, consumed.

    Returns:
        The final carry, or the initial carry when the bounds are empty.

    Raises:
        The body's exact error type; execution stops without rolling back state.
    """
    return _indexed[A, Pointer[F, origin_of(body_fun)], F.Error,
        _indexed_repeated[A, F, origin_of(body_fun)], unroll, True, lower, upper](
        lower, upper, Pointer(to=body_fun), init_val^)


def fori_loop[A: Movable & Deinitable, F: BinaryContract & Movable & Deinitable,
              //, unroll: Int = 1](
    lower: Int, upper: Int, var body_fun: F, var init_val: A
) raises F.Error -> A where RepeatableBinary[F] and F.First == Int and F.Second == A and F.Out == A:
    """Consume a repeatable body and run a dynamically bounded counted loop.

    Mutable invocation wins over shared invocation. The owner is destroyed
    after success or failure, including for empty bounds. Pass `mut_ref(body)`
    to retain the original receiver and its state. The carry moves through
    each step without copying. Bounds and unrolling follow `fori_loop_mut`.

    Parameters:
        A: The exact carry type, including its borrowed origins.
        F: A shared or mutable binary callback taking (Int, carry).
        unroll: Steps per rolled iteration; positive for dynamic bounds.

    Args:
        lower: The first index.
        upper: The excluded upper bound.
        body_fun: The callback owner, consumed for the entire loop.
        init_val: The initial carry, consumed.

    Returns:
        The final carry, or the initial carry when the bounds are empty.

    Raises:
        The body's exact error; execution stops before the next step.
    """
    return fori_loop_mut[unroll=unroll](lower, upper, body_fun, init_val^)


def fori_loop[A: Movable & Deinitable, F: BinaryContract & Movable & Deinitable,
              //, lower: Int, upper: Int, unroll: Int = 1](
    var body_fun: F, var init_val: A
) raises F.Error -> A where RepeatableBinary[F] and F.First == Int and F.Second == A and F.Out == A:
    """Consume a repeatable body and run a statically bounded counted loop.

    Receiver choice, errors and ownership follow the dynamic owned form.
    `unroll=0` fully expands the same ordered steps. The body is destroyed
    even for empty bounds; `mut_ref(body)` retains its original state.

    Parameters:
        A: The exact carry type, including its borrowed origins.
        F: A shared or mutable binary callback taking (Int, carry).
        lower: The first index, known at compile time.
        upper: The excluded upper bound, known at compile time.
        unroll: Steps per rolled iteration, or zero for full static expansion.

    Args:
        body_fun: The callback owner, consumed for the entire loop.
        init_val: The initial carry, consumed.

    Returns:
        The final carry, or the initial carry when the bounds are empty.

    Raises:
        The body's exact error; execution stops before the next step.
    """
    return fori_loop_mut[lower, upper, unroll=unroll](body_fun, init_val^)


def while_loop[A: Movable & Deinitable, P: BorrowCallable, F: UnaryContract & Movable & Deinitable,
                    //, E: Movable & Deinitable = _CommonError[P.Failure, F.Error]](
    cond_fun: P, var body_fun: F, var init_val: A
) raises E -> A:
    """Run a while loop with an owned repeatable library body.

    Mutable body invocation wins over shared invocation. A false predicate
    returns the current carry without a body call; failure stops immediately.
    The body is destroyed on every path, including when the first predicate is
    false. Pass `mut_ref(body)` to retain the original receiver and its state.
    The named shared predicate remains borrowed.

    Parameters:
        A: The carry type, including move-only payloads and borrowed origins.
        P: A repeatable borrowing predicate returning Bool.
        F: A repeatable unary body taking and returning the exact carry type.
        E: The exact common error, normally inferred; generic wrappers may select it.

    Args:
        cond_fun: The borrowed shared predicate.
        body_fun: The library body owner, consumed without copying.
        init_val: The initial carry, consumed without copying.

    Returns:
        The carry for which the predicate first returned False.

    Raises:
        The exact predicate or body error. Their errors must match, including
        origins, or one must be Never. Retained receiver updates survive failure.
    """
    return while_loop_mut[E=E](cond_fun, body_fun, init_val^)


def while_loop[A: Movable & Deinitable, P: BorrowCallContract & Movable & Deinitable, F: UnaryContract & Movable & Deinitable,
                    //, E: Movable & Deinitable = _CommonError[P.Failure, F.Error]](
    var cond_fun: P, var body_fun: F, var init_val: A
) raises E -> A:
    """Run a while loop with an owned repeatable library body.

    Mutable body invocation wins over shared invocation. A false predicate
    returns the current carry without a body call; failure stops immediately.
    The body is destroyed on every path, including when the first predicate is
    false. Pass `mut_ref(body)` to retain the original receiver and its state.
    The predicate is consumed too; mutable invocation wins over shared.
    Pass `mut_ref(predicate)` to retain its state after the loop.

    Parameters:
        A: The carry type, including move-only payloads and borrowed origins.
        P: A repeatable borrowing predicate returning Bool.
        F: A repeatable unary body taking and returning the exact carry type.
        E: The exact common error, normally inferred; generic wrappers may select it.

    Args:
        cond_fun: The predicate owner, consumed.
        body_fun: The library body owner, consumed without copying.
        init_val: The initial carry, consumed without copying.

    Returns:
        The carry for which the predicate first returned False.

    Raises:
        The exact predicate or body error. Their errors must match, including
        origins, or one must be Never. Retained receiver updates survive failure.
    """
    return while_loop_mut[E=E](cond_fun^, body_fun, init_val^)


def while_loop[A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, R: RegisterPassable & Deinitable,
                    //, E: Movable & Deinitable = F.Error](
    cond_fun: def(A) thin -> R,
    var body_fun: F,
    var init_val: A
) raises E -> A where not conforms_to(A, TrivialRegisterPassable) and R == Bool and _WhileBody[A, F]:
    """Run a while loop with an owned repeatable library body.

    Mutable body invocation wins over shared invocation. A false predicate
    returns the current carry without a body call; failure stops immediately.
    The body is destroyed on every path, including when the first predicate is
    false. Pass `mut_ref(body)` to retain the original receiver and its state.
    The native predicate is a plain function or stored thin pointer.
    Capture a closure with `BorrowSignature[A, Bool, PE].capture(predicate)`.

    Parameters:
        A: The carry type, including move-only payloads and borrowed origins.
        F: A repeatable unary body taking and returning the exact carry type.
        R: The native predicate result, required to equal Bool.
        E: The exact common error, normally inferred; generic wrappers may select it.

    Args:
        cond_fun: The native predicate reading the current carry.
        body_fun: The library body owner, consumed without copying.
        init_val: The initial carry, consumed without copying.

    Returns:
        The carry for which the predicate first returned False.

    Raises:
        The exact predicate or body error. Their errors must match, including
        origins, or one must be Never. Retained receiver updates survive failure.
    """
    return while_loop_mut[E=E](cond_fun, body_fun, init_val^)


def while_loop[A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, B: TrivialRegisterPassable, R: RegisterPassable & Deinitable,
                    //, E: Movable & Deinitable = F.Error](
    cond_fun: def(B) thin -> R,
    var body_fun: F,
    var init_val: A
) raises E -> A where B == A and R == Bool and _WhileBody[A, F]:
    """Run a while loop with an owned repeatable library body.

    Mutable body invocation wins over shared invocation. A false predicate
    returns the current carry without a body call; failure stops immediately.
    The body is destroyed on every path, including when the first predicate is
    false. Pass `mut_ref(body)` to retain the original receiver and its state.
    The native predicate is a plain function or stored thin pointer.
    Capture a closure with `BorrowSignature[A, Bool, PE].capture(predicate)`.

    Parameters:
        A: The carry type, including move-only payloads and borrowed origins.
        F: A repeatable unary body taking and returning the exact carry type.
        B: The native register input, required to equal A.
        R: The native predicate result, required to equal Bool.
        E: The exact common error, normally inferred; generic wrappers may select it.

    Args:
        cond_fun: The native predicate reading the current carry.
        body_fun: The library body owner, consumed without copying.
        init_val: The initial carry, consumed without copying.

    Returns:
        The carry for which the predicate first returned False.

    Raises:
        The exact predicate or body error. Their errors must match, including
        origins, or one must be Never. Retained receiver updates survive failure.
    """
    return while_loop_mut[E=E](cond_fun, body_fun, init_val^)


def while_loop[A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, R: RegisterPassable & Deinitable, PE: Movable & Deinitable,
                    //, E: Movable & Deinitable = _CommonError[PE, F.Error]](
    cond_fun: def(A) raises PE thin -> R,
    var body_fun: F,
    var init_val: A
) raises E -> A where not conforms_to(A, TrivialRegisterPassable) and R == Bool and _WhileBody[A, F] and _CommonErrorCompatible[PE, F.Error]:
    """Run a while loop with an owned repeatable library body.

    Mutable body invocation wins over shared invocation. A false predicate
    returns the current carry without a body call; failure stops immediately.
    The body is destroyed on every path, including when the first predicate is
    false. Pass `mut_ref(body)` to retain the original receiver and its state.
    The native predicate is a plain function or stored thin pointer.
    Capture a closure with `BorrowSignature[A, Bool, PE].capture(predicate)`.

    Parameters:
        A: The carry type, including move-only payloads and borrowed origins.
        F: A repeatable unary body taking and returning the exact carry type.
        R: The native predicate result, required to equal Bool.
        PE: The exact native predicate error.
        E: The exact common error, normally inferred; generic wrappers may select it.

    Args:
        cond_fun: The native predicate reading the current carry.
        body_fun: The library body owner, consumed without copying.
        init_val: The initial carry, consumed without copying.

    Returns:
        The carry for which the predicate first returned False.

    Raises:
        The exact predicate or body error. Their errors must match, including
        origins, or one must be Never. Retained receiver updates survive failure.
    """
    return while_loop_mut[E=E](cond_fun, body_fun, init_val^)


def while_loop[A: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, B: TrivialRegisterPassable, R: RegisterPassable & Deinitable, PE: Movable & Deinitable,
                    //, E: Movable & Deinitable = _CommonError[PE, F.Error]](
    cond_fun: def(B) raises PE thin -> R,
    var body_fun: F,
    var init_val: A
) raises E -> A where B == A and R == Bool and _WhileBody[A, F] and _CommonErrorCompatible[PE, F.Error]:
    """Run a while loop with an owned repeatable library body.

    Mutable body invocation wins over shared invocation. A false predicate
    returns the current carry without a body call; failure stops immediately.
    The body is destroyed on every path, including when the first predicate is
    false. Pass `mut_ref(body)` to retain the original receiver and its state.
    The native predicate is a plain function or stored thin pointer.
    Capture a closure with `BorrowSignature[A, Bool, PE].capture(predicate)`.

    Parameters:
        A: The carry type, including move-only payloads and borrowed origins.
        F: A repeatable unary body taking and returning the exact carry type.
        B: The native register input, required to equal A.
        R: The native predicate result, required to equal Bool.
        PE: The exact native predicate error.
        E: The exact common error, normally inferred; generic wrappers may select it.

    Args:
        cond_fun: The native predicate reading the current carry.
        body_fun: The library body owner, consumed without copying.
        init_val: The initial carry, consumed without copying.

    Returns:
        The carry for which the predicate first returned False.

    Raises:
        The exact predicate or body error. Their errors must match, including
        origins, or one must be Never. Retained receiver updates survive failure.
    """
    return while_loop_mut[E=E](cond_fun, body_fun, init_val^)
