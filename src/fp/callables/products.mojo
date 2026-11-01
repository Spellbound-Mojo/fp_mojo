"""Move both elements out of a native pair without copying either."""
from std.builtin.rebind import rebind_var, rebind, downcast
from std.memory import MaybeUninit
from .protocols import UnaryContract, Unary, OnceUnary, MutableUnary, BinaryContract
from .invoke import call_once, RepeatableUnary, _OnceBinaryAvailable
from ._receiver import _MutableUnaryRef, _SharedUnaryRef, _binary_once_as
from ._views import _UnaryViewable
from fp._internal.errors import _ErrorCompatible


comptime _OptionalCell[T: Movable & Deinitable]: Movable & Deinitable = Optional[T]

def _take_pair[A: Movable & Deinitable, B: Movable & Deinitable](
    var pair: Tuple[A, B], mut first: MaybeUninit[A], mut second: MaybeUninit[B]
):
    """Move both elements of a native pair into uninitialized caller slots.

    Untagged slots keep the split to plain moves. Each caller takes both slots
    with `unsafe_assume_init` immediately afterwards."""
    def put[index: Int](var value: Tuple[A, B].Ts[index]) {ref first, ref second}:
        comptime if index == 0:
            first.unsafe_ptr().unsafe_write(rebind_var[A](value^))
        else:
            second.unsafe_ptr().unsafe_write(rebind_var[B](value^))
    pair^.consume_elements(put)


def _call_pair_as[E: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](
    var function: F, var pair: Tuple[F.First, F.Second]
) raises E -> F.Out where _ErrorCompatible[E, F.Error] and _OnceBinaryAvailable[F]:
    """Transfer a native pair to one binary call through the canonical receiver."""
    var first = MaybeUninit[F.First]()
    var second = MaybeUninit[F.Second]()
    _take_pair(pair^, first, second)
    return _binary_once_as[E](function^, first^.unsafe_assume_init(), second^.unsafe_assume_init())


@fieldwise_init
struct _WithSecond[A: Movable & Deinitable, S: Movable & Deinitable](OnceUnary, MutableUnary where conforms_to(S, Copyable)):
    """Pair each base payload with an owned second value; repeated pairing copies it."""
    var second: Self.S
    comptime Arg = Self.A
    comptime Out = Tuple[Self.A, Self.S]
    def call_once(deinit self, var arg: Self.Arg) -> Self.Out:
        return Tuple(arg^, self.second^)
    def call_mut(mut self, var arg: Self.Arg) -> Self.Out:
        comptime C = downcast[Self.S, Copyable & Deinitable]
        return Tuple(arg^, rebind_var[Self.S](rebind[C](self.second).copy()))


@fieldwise_init
struct MappedPair[F: UnaryContract & Movable & Deinitable, Other: Movable & Deinitable, first: Bool](
    OnceUnary, Unary where conforms_to(F, Unary),
    _UnaryViewable where conforms_to(F, Unary),
    MutableUnary where RepeatableUnary[F], Copyable where conforms_to(F, Copyable)
):
    """Transform one pair element and move the other through unchanged.

    Returned by `fp.functions.first` and `fp.functions.second`. The callback
    moves into the wrapper without being called or copied. Calls consume the
    pair, apply the callback to its selected element, and return a new pair.
    The other element needs no copy capability. Exact result and error types,
    receiver requirements and embedded origins are preserved.

    Named shared wrappers can be reused by borrow in supported unary operations.
    Move the wrapper to transfer its callback. Mutable calls retain callback
    state, and consuming calls transfer its captures to the selected invocation.

    Parameters:
        F: The unary library callback's type.
        Other: The untouched pair element's type.
        first: Whether the selected element is first rather than second.
    """
    var function: Self.F
    comptime Arg = Tuple[Self.F.Arg, Self.Other] if Self.first else Tuple[Self.Other, Self.F.Arg]
    comptime Out = Tuple[Self.F.Out, Self.Other] if Self.first else Tuple[Self.Other, Self.F.Out]
    comptime Error = Self.F.Error
    comptime _View[o: ImmOrigin] = _SharedUnaryRef[downcast[Self, Unary], o]

    def _unary_view[o: ImmOrigin](ref[o] self) -> Self._View[o]:
        comptime assert conforms_to(Self.F, Unary)
        return Self._View[o](Pointer(to=self))

    def call(self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        """Transform the selected element through a shared callback receiver.

        Args:
            arg: The native pair, consumed without copying either element.

        Returns:
            The mapped pair with its untouched element transferred unchanged.

        Raises:
            The callback's exact error type.
        """
        comptime assert conforms_to(Self.F, Unary), "pair mapping: a shared call requires a Unary"
        comptime C = downcast[Self.F, Unary]
        ref callback = rebind[C](self.function)
        comptime V = _SharedUnaryRef[C, origin_of(callback)]
        comptime assert Self.Arg == _MapPair[V, Self.Other, Self.first].Arg
        return rebind_var[Self.Out](_map_pair[Self.Other, Self.first](
            V(Pointer(to=callback)), rebind_var[_MapPair[V, Self.Other, Self.first].Arg](arg^)))

    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        """Transform once, consuming the callback and both pair elements.

        Args:
            arg: The native pair, consumed.

        Returns:
            The mapped pair with its untouched element transferred unchanged.

        Raises:
            The callback's exact error type.
        """
        return _map_pair[Self.Other, Self.first](self.function^, arg^)

    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        """Transform with exclusive access, retaining callback state for later calls.

        Args:
            arg: The native pair, consumed.

        Returns:
            The mapped pair with its untouched element transferred unchanged.

        Raises:
            The callback's exact error type.
        """
        comptime assert RepeatableUnary[Self.F], "pair mapping: a repeated call requires a shared or mutable Unary"
        return _map_pair[Self.Other, Self.first](_MutableUnaryRef[Self.F, origin_of(self.function)](Pointer(to=self.function)), arg^)

    def __call__(self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        """Transform through a shared receiver, as `call` does.

        Args:
            arg: The native pair, consumed.

        Returns:
            The mapped pair with its untouched element transferred unchanged.

        Raises:
            The callback's exact error type.
        """
        return self.call(arg^)


# Preserve the existing internal type spelling for State, Writer and transport.
comptime _MapPair[F: UnaryContract & Movable & Deinitable, Other: Movable & Deinitable, first: Bool] = MappedPair[F, Other, first]


def _map_pair[Other: Movable & Deinitable, first: Bool, F: UnaryContract & Movable & Deinitable](
    var function: F, var pair: _MapPair[F, Other, first].Arg
) raises F.Error -> _MapPair[F, Other, first].Out:
    var value_slot = MaybeUninit[F.Arg]()
    var other_slot = MaybeUninit[Other]()
    comptime if first:
        _take_pair(rebind_var[Tuple[F.Arg, Other]](pair^), value_slot, other_slot)
    else:
        _take_pair(rebind_var[Tuple[Other, F.Arg]](pair^), other_slot, value_slot)
    var value = value_slot^.unsafe_assume_init()
    var other = other_slot^.unsafe_assume_init()
    var mapped = call_once(function^, value^)
    comptime if first:
        return rebind_var[_MapPair[F, Other, first].Out](Tuple(mapped^, other^))
    else:
        return rebind_var[_MapPair[F, Other, first].Out](Tuple(other^, mapped^))
