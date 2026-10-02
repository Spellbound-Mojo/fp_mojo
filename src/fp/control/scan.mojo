"""Eager carry/output scans over native finite sequences."""
from std.iter import Iterator
from std.utils import Variant
from std.builtin.rebind import rebind_var
from std.memory import MaybeUninit
from fp.callables.products import _take_pair
from fp.callables.protocols import Binary
from fp.iteration._terminal import _collect_list
from fp._internal.errors import _propagate_error
from ._loops import _indexed


@fieldwise_init
struct ScanLengthError(Copyable, Movable, Writable):
    """A `scan` length that is negative, missing or different from the input's; no callback has run."""
    var expected: Int
    """The length the scan required."""
    var actual: Int
    """The length it was given; `-1` when no length was given."""


@fieldwise_init
struct ScanStepError[E: Movable & Deinitable](Movable, Copyable where conforms_to(E, Copyable)):
    """A `scan` step's error, kept distinct from a length error.

    A step that raises `StopIteration` is reported here too: it is a step error,
    not exhaustion.

    Parameters:
        E: The step's error type.
    """
    var error: Self.E
    """The step's error, unchanged."""


comptime ScanError[E: Movable & Deinitable] = ScanLengthError if E == Never else Variant[ScanLengthError, ScanStepError[E]]
"""The error of `scan`: `ScanLengthError` alone for a pure step, otherwise a native `Variant` of it and `ScanStepError[E]`.

Parameters:
    E: The step's error type; `Never` for a pure step.
"""


def _length_error[E: Movable & Deinitable](expected: Int, actual: Int) raises ScanError[E] -> Never:
    comptime if E == Never:
        raise rebind_var[ScanError[E]](ScanLengthError(expected, actual))
    else:
        raise rebind_var[ScanError[E]](Variant[ScanLengthError, ScanStepError[E]](ScanLengthError(expected, actual)))


def _length[E: Movable & Deinitable, static_length: Int, no_input: Bool](
    actual: Int, length: Optional[Int]
) raises ScanError[E] -> Int:
    comptime assert static_length >= -1, "scan: static_length must be nonnegative or omitted"
    var count = actual
    if length:
        count = length.value()
        if count < 0:
            _length_error[E](0, count)
    elif no_input:
        comptime if static_length >= 0:
            count = static_length
        else:
            _length_error[E](0, -1)
    if not no_input and count != actual:
        _length_error[E](count, actual)
    comptime if static_length >= 0:
        if count != static_length:
            _length_error[E](static_length, count)
    return count


def _scan_item[X: Movable & Deinitable, no_input: Bool](mut xs: List[X]) -> X:
    comptime if no_input:
        comptime assert X == Tuple[]
        return rebind_var[X](Tuple())
    else:
        return xs.pop()


# Keep the tuple result structural in these native signatures. Mojo 1.1 does
# not recover it through the independent R parameter of _binary_plain/raising.
# These bridges only apply a native signature; all scan behavior is shared.
def _scan_plain[A: Movable & Deinitable, X: Movable & Deinitable,
                Y: Movable & Deinitable, F: def(var A, var X) -> Tuple[A, Y]](
    var carry: A, var value: X, function: F
) capturing -> Tuple[A, Y]:
    return function(carry^, value^)


def _scan_raising[A: Movable & Deinitable, X: Movable & Deinitable,
                  Y: Movable & Deinitable, E: Movable & Deinitable,
                  F: def(var A, var X) raises E -> Tuple[A, Y]](
    var carry: A, var value: X, function: F
) raises E capturing -> Tuple[A, Y]:
    return function(carry^, value^)


@fieldwise_init
struct _ScanState[A: Movable & Deinitable, Y: Movable & Deinitable](Movable):
    var carry: Optional[Self.A]
    var outputs: List[Self.Y]

    def into_result(deinit self) -> Tuple[Self.A, List[Self.Y]]:
        return (self.carry.take(), self.outputs^)


# Mojo 1.1 O3 crashes when an always-raising native step is inlined through
# the carried tuple and its cleanup paths. Retain this native call boundary;
# chunk/full scheduling still expands in _indexed and errors keep their type.
@no_inline
def _scan_step[A: Movable & Deinitable, X: Movable & Deinitable,
               Y: Movable & Deinitable, F: AnyType, E: Movable & Deinitable,
               fo: ImmOrigin, xo: MutOrigin, no_input: Bool,
               apply: def(var A, var X, F) raises E capturing -> Tuple[A, Y]](
    var state: _ScanState[A, Y], index: Int,
    context: Tuple[Pointer[F, fo], Pointer[List[X], xo]]
) raises E capturing -> _ScanState[A, Y]:
    var value = _scan_item[X, no_input](context[1][])
    var pair = apply(state.carry.take(), value^, context[0][])
    # Native tuples have a consuming pack boundary rather than movable indexed
    # references; split the pair into untagged slots.
    var carry = MaybeUninit[A]()
    var output = MaybeUninit[Y]()
    _take_pair(pair^, carry, output)
    state.outputs.append(output^.unsafe_assume_init())
    state.carry = Optional(carry^.unsafe_assume_init())
    return state^


def _scan[A: Movable & Deinitable, X: Movable & Deinitable,
          Y: Movable & Deinitable, F: AnyType, E: Movable & Deinitable,
          apply: def(var A, var X, F) raises E capturing -> Tuple[A, Y],
          unroll: Int, static_length: Int, no_input: Bool = False](
    function: F, var initial: A, var xs: List[X], length: Optional[Int], reverse: Bool
) raises ScanError[E] -> Tuple[A, List[Y]]:
    var count = _length[E, static_length, no_input](len(xs), length)
    # Native List reversal and pop move elements, including noncopyable values.
    # Pop gives forward input order after reversal, reverse order without it.
    if not reverse:
        xs.reverse()
    comptime C = Tuple[Pointer[F, origin_of(function)], Pointer[List[X], origin_of(xs)]]
    var result: _ScanState[A, Y]
    try:
        result = _indexed[_ScanState[A, Y], C, E,
            _scan_step[A, X, Y, F, E, origin_of(function), origin_of(xs), no_input, apply],
            unroll, static_length >= 0, 0, static_length](
            0, count, (Pointer(to=function), Pointer(to=xs)), _ScanState[A, Y](Optional(initial^), List[Y]()))
    except error:
        comptime if E == Never:
            _propagate_error[ScanError[E]](error^)
        else:
            raise rebind_var[ScanError[E]](Variant[ScanLengthError, ScanStepError[E]](ScanStepError[E](error^)))
    if reverse:
        result.outputs.reverse()
    return result^.into_result()


def _scan_fixed[A: Movable & Deinitable, X: Movable & Deinitable,
                Y: Movable & Deinitable, F: Binary](
    var carry: A, var value: X, function: F
) raises F.Error capturing -> Tuple[A, Y]:
    comptime assert F.First == A and F.Second == X and F.Out == Tuple[A, Y], "scan: the step must take (carry, element) and return (carry, output)"
    return rebind_var[Tuple[A, Y]](function.call(rebind_var[F.First](carry^), rebind_var[F.Second](value^)))


# Native conformance distinguishes pure and raising callbacks. Binary library
# callables use an explicit Y parameter, as with iteration.filter_map[U].
# Every facade shares length validation, movement, scheduling and cleanup.


def scan[A: Movable & Deinitable,
         X: Movable & Deinitable,
         Y: Movable & Deinitable,
         F: def(var A, var X) -> Tuple[A, Y],
         //,
         unroll: Int = 1,
         static_length: Int = -1](
    f: F, var init: A, var xs: List[X], *, length: Optional[Int] = None, reverse: Bool = False
) raises ScanError[Never] -> Tuple[A, List[Y]]:
    """Thread a carry through a sequence, collecting one output per element.

    The step receives `(carry, element)` and returns `(next_carry, output)`;
    the carry and output may have different types, and neither is copied. The
    initial carry is not emitted (`fp.iteration.scan_left` emits snapshots
    instead). Empty input returns the initial carry and an empty list. An
    iterator input is collected into a `List` first, so it must be finite, and
    every pull finishes before the first step. With no input, give `length` or
    `static_length`; the step then receives `Tuple[]`. In reverse, running sums
    over `[1, 2, 3]` give the carry `6` and the outputs `[6, 5, 3]`. On failure
    the partial outputs, unused inputs and carry are destroyed.

    Parameters:
        A: The carry type.
        X: The element type.
        Y: The output type.
        F: The step's type: a plain function or a closure.
        unroll: How many steps each rolled iteration expands: `1`, the default,
            keeps a rolled loop, and `0` fully expands a scan of `static_length`.
        static_length: The input length, known when the program compiles; `-1`
            when it is not.

    Args:
        f: The step, borrowed.
        init: The first carry, consumed.
        xs: The elements, consumed.
        length: The input's length, checked against it; it does not truncate.
        reverse: Whether the steps run from the last element to the first. The
            outputs keep the positions of their inputs.

    Returns:
        The final carry and the outputs, in input order.

    Raises:
        `ScanLengthError` for a negative, missing or different length, before
        any step runs.
    """
    return _scan[A, X, Y, F, Never, _scan_plain[A, X, Y, F], unroll, static_length](
        f, init^, xs^, length, reverse)


def scan[A: Movable & Deinitable,
         X: Movable & Deinitable,
         Y: Movable & Deinitable,
         E: Movable & Deinitable,
         F: def(var A, var X) raises E -> Tuple[A, Y],
         //,
         unroll: Int = 1,
         static_length: Int = -1](
    f: F, var init: A, var xs: List[X], *, length: Optional[Int] = None, reverse: Bool = False
) raises ScanError[E] -> Tuple[A, List[Y]]:
    """Scan a `List` with a raising step; its error arrives as `ScanStepError[E]`."""
    return _scan[A, X, Y, F, E, _scan_raising[A, X, Y, E, F], unroll, static_length](
        f, init^, xs^, length, reverse)


def scan[A: Movable & Deinitable,
         X: Movable & Deinitable,
         F: Binary,
         //,
         Y: Movable & Deinitable,
         unroll: Int = 1,
         static_length: Int = -1](
    f: F, var init: A, var xs: List[X], *, length: Optional[Int] = None, reverse: Bool = False
) raises ScanError[F.Error] -> Tuple[A, List[Y]] where F.First == A and F.Second == X and F.Out == Tuple[A, Y]:
    """Scan a `List` with a library `Binary` step; name the output type, `scan[Y](step, ...)`."""
    return _scan[A, X, Y, F, F.Error, _scan_fixed[A, X, Y, F], unroll, static_length](
        f, init^, xs^, length, reverse)


def scan[A: Movable & Deinitable,
         X: Movable & Deinitable,
         Y: Movable & Deinitable,
         I: Iterator,
         F: def(var A, var X) -> Tuple[A, Y],
         //,
         unroll: Int = 1,
         static_length: Int = -1](
    f: F, var init: A, var xs: I, *, length: Optional[Int] = None, reverse: Bool = False
) raises ScanError[Never] -> Tuple[A, List[Y]] where I.Element == X:
    """Scan a finite iterator, collected into a `List` before the first step."""
    return _scan[A, X, Y, F, Never, _scan_plain[A, X, Y, F], unroll, static_length](
        f, init^, _collect_list[X, I](xs^), length, reverse)


def scan[A: Movable & Deinitable,
         X: Movable & Deinitable,
         Y: Movable & Deinitable,
         I: Iterator,
         E: Movable & Deinitable,
         F: def(var A, var X) raises E -> Tuple[A, Y],
         //,
         unroll: Int = 1,
         static_length: Int = -1](
    f: F, var init: A, var xs: I, *, length: Optional[Int] = None, reverse: Bool = False
) raises ScanError[E] -> Tuple[A, List[Y]] where I.Element == X:
    """Scan a finite iterator with a raising step."""
    return _scan[A, X, Y, F, E, _scan_raising[A, X, Y, E, F], unroll, static_length](
        f, init^, _collect_list[X, I](xs^), length, reverse)


def scan[A: Movable & Deinitable,
         I: Iterator,
         F: Binary,
         //,
         Y: Movable & Deinitable,
         unroll: Int = 1,
         static_length: Int = -1](
    f: F, var init: A, var xs: I, *, length: Optional[Int] = None, reverse: Bool = False
) raises ScanError[F.Error] -> Tuple[A, List[Y]] where F.First == A and F.Second == I.Element and F.Out == Tuple[A, Y]:
    """Scan a finite iterator with a library `Binary` step."""
    return _scan[A, F.Second, Y, F, F.Error, _scan_fixed[A, F.Second, Y, F], unroll, static_length](
        f, init^, _collect_list[F.Second, I](xs^), length, reverse)


def scan[A: Movable & Deinitable,
         Y: Movable & Deinitable,
         F: def(var A, var Tuple[]) -> Tuple[A, Y],
         //,
         unroll: Int = 1,
         static_length: Int = -1](
    f: F, var init: A, *, length: Optional[Int] = None, reverse: Bool = False
) raises ScanError[Never] -> Tuple[A, List[Y]]:
    """Scan `length` times with no input; the step receives `Tuple[]`."""
    return _scan[A, Tuple[], Y, F, Never, _scan_plain[A, Tuple[], Y, F], unroll, static_length, True](
        f, init^, List[Tuple[]](), length, reverse)


def scan[A: Movable & Deinitable,
         Y: Movable & Deinitable,
         E: Movable & Deinitable,
         F: def(var A, var Tuple[]) raises E -> Tuple[A, Y],
         //,
         unroll: Int = 1,
         static_length: Int = -1](
    f: F, var init: A, *, length: Optional[Int] = None, reverse: Bool = False
) raises ScanError[E] -> Tuple[A, List[Y]]:
    """Scan `length` times with no input and a raising step."""
    return _scan[A, Tuple[], Y, F, E, _scan_raising[A, Tuple[], Y, E, F], unroll, static_length, True](
        f, init^, List[Tuple[]](), length, reverse)


def scan[A: Movable & Deinitable,
         F: Binary,
         //,
         Y: Movable & Deinitable,
         unroll: Int = 1,
         static_length: Int = -1](
    f: F, var init: A, *, length: Optional[Int] = None, reverse: Bool = False
) raises ScanError[F.Error] -> Tuple[A, List[Y]] where F.First == A and F.Second == Tuple[] and F.Out == Tuple[A, Y]:
    """Scan `length` times with no input and a library `Binary` step."""
    return _scan[A, Tuple[], Y, F, F.Error, _scan_fixed[A, Tuple[], Y, F], unroll, static_length, True](
        f, init^, List[Tuple[]](), length, reverse)
