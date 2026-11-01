"""Canonical concatenation monoids; user monoids implement the same protocol."""
from .protocols import Monoid, Semigroup, _start_as, _combine_as
from ._accumulation import _Combine, _OptionalCombine
from fp.callables.products import _take_pair
from fp._internal.errors import _CommonError, _ErrorCompatible
from std.memory import MaybeUninit
from std.collections import KeyElement
from std.os import abort
from std.builtin.rebind import downcast
from std.iter import IterableOwned
from .instances import _ListElement


struct StringMonoid(Monoid):
    """String concatenation, with the empty string as identity."""
    comptime Value = String
    comptime Error = Never

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
    comptime Error = Never

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



struct _NoMonoidValue(Movable):
    def __init__(out self):
        pass


struct _NoMonoid(Monoid):
    """The default for a type without a canonical monoid; its Value matches nothing."""
    comptime Value = _NoMonoidValue
    comptime Error = Never

    @staticmethod
    def empty() -> Self.Value:
        return _NoMonoidValue()

    @staticmethod
    def combine(var left: Self.Value, var right: Self.Value) -> Self.Value:
        return left^


# A type with one natural monoid selects it: String and List concatenate.
# Numbers have no canonical choice (sum or product), so they stay explicit;
# any other type selects _NoMonoid, whose Value matches no callback or source,
# so the call is rejected and an explicit monoid still binds.
comptime _CanonicalMonoid[V: Movable & Deinitable]: Monoid = downcast[
    StringMonoid if V == String else
    (ListMonoid[_ListElement[V]] if V == List[_ListElement[V]] else _NoMonoid)
    if conforms_to(V, IterableOwned) else _NoMonoid,
    Monoid,
]

struct IntSumMonoid(Monoid):
    """Native Int addition with zero identity; overflow follows native Int arithmetic."""
    comptime Value = Int
    @staticmethod
    def empty() -> Int:
        """Return the additive identity.

        Returns:
            Zero.
        """
        return 0
    @staticmethod
    def combine(var left: Int, var right: Int) -> Int:
        """Add two native integers.

        Args:
            left: The first operand.
            right: The second operand.

        Returns:
            Their native sum.
        """
        return left + right


struct IntProductMonoid(Monoid):
    """Native Int multiplication with one identity; overflow follows native arithmetic."""
    comptime Value = Int
    @staticmethod
    def empty() -> Int:
        """Return one, the multiplicative identity.

        Returns:
            One.
        """
        return 1
    @staticmethod
    def combine(var left: Int, var right: Int) -> Int:
        """Multiply two native integers.

        Args:
            left: The first operand.
            right: The second operand.

        Returns:
            Their native product.
        """
        return left * right


struct SIMDSumMonoid[dtype: DType, size: SIMDLength](Monoid):
    """Ordered lane-wise numeric addition, with native arithmetic semantics.

    Floating-point addition is not associative. Floating instances are ordered
    accumulation policies, not a license to reassociate or parallelize a fold.

    Parameters:
        dtype: An integral or floating-point element type.
        size: The number of lanes.
    """
    comptime Value = SIMD[Self.dtype, Self.size]
    comptime Admitted = Self.dtype.is_integral() or Self.dtype.is_floating_point()
    @staticmethod
    def empty() -> Self.Value:
        """Return a zero in every lane.

        Returns:
            The numeric zero vector.
        """
        comptime assert Self.Admitted, "sum: numeric dtype required"
        return Self.Value(0)
    @staticmethod
    def combine(var left: Self.Value, var right: Self.Value) -> Self.Value:
        """Add matching lanes without reducing or reassociating them.

        Args:
            left: The earlier vector.
            right: The later vector.

        Returns:
            Their lane-wise sum.
        """
        comptime assert Self.Admitted, "sum: numeric dtype required"
        return left + right


struct BoolAllMonoid(Monoid):
    """Boolean conjunction with True identity; operands are already evaluated."""
    comptime Value = Bool
    @staticmethod
    def empty() -> Bool:
        """Return True.

        Returns:
            The conjunction identity.
        """
        return True
    @staticmethod
    def combine(var left: Bool, var right: Bool) -> Bool:
        """Conjoin two already evaluated booleans.

        Args:
            left: The first boolean.
            right: The second boolean.

        Returns:
            True only when both operands are true.
        """
        return left and right


struct BoolAnyMonoid(Monoid):
    """Boolean disjunction with False identity; operands are already evaluated."""
    comptime Value = Bool
    @staticmethod
    def empty() -> Bool:
        """Return False.

        Returns:
            The disjunction identity.
        """
        return False
    @staticmethod
    def combine(var left: Bool, var right: Bool) -> Bool:
        """Disjoin two already evaluated booleans.

        Args:
            left: The first boolean.
            right: The second boolean.

        Returns:
            True when either operand is true.
        """
        return left or right


struct ProductMonoid[L: Monoid, R: Monoid](Monoid):
    """Combine native pairs component-wise, first component before second.

    Nest this dictionary for larger products. Each component moves exactly
    once. The second operation is skipped if the first raises; native cleanup
    destroys all unconsumed components. Errors must be identical or Never.

    Parameters:
        L: The first component's monoid.
        R: The second component's monoid.
    """
    comptime Value = Tuple[Self.L.Value, Self.R.Value]
    comptime Error = _CommonError[Self.L.Error, Self.R.Error]
    @staticmethod
    def empty() raises Self.Error -> Self.Value:
        """Construct the two identities from left to right.

        Returns:
            A native pair of identities.

        Raises:
            The exact common component error.
        """
        comptime assert _ErrorCompatible[Self.Error, Self.L.Error] and _ErrorCompatible[Self.Error, Self.R.Error], "ProductMonoid: incompatible component errors"
        var first = _start_as[Self.Error, _Combine[Self.L]]()
        var second = _start_as[Self.Error, _Combine[Self.R]]()
        return (first^, second^)
    @staticmethod
    def combine(var left: Self.Value, var right: Self.Value) raises Self.Error -> Self.Value:
        """Combine corresponding owned components in component order.

        Args:
            left: The earlier pair, consumed.
            right: The later pair, consumed.

        Returns:
            A pair of combined components, without copying payloads.

        Raises:
            The exact common component error, stopping immediately.
        """
        comptime assert _ErrorCompatible[Self.Error, Self.L.Error] and _ErrorCompatible[Self.Error, Self.R.Error], "ProductMonoid: incompatible component errors"
        var la = MaybeUninit[Self.L.Value]()
        var lb = MaybeUninit[Self.R.Value]()
        var ra = MaybeUninit[Self.L.Value]()
        var rb = MaybeUninit[Self.R.Value]()
        _take_pair(left^, la, lb)
        _take_pair(right^, ra, rb)
        var a = la^.unsafe_assume_init()
        var b = lb^.unsafe_assume_init()
        var c = ra^.unsafe_assume_init()
        var d = rb^.unsafe_assume_init()
        var first = _combine_as[Self.Error, _Combine[Self.L]](a^, c^)
        var second = _combine_as[Self.Error, _Combine[Self.R]](b^, d^)
        return (first^, second^)


struct OptionalMonoid[S: Semigroup](Monoid):
    """Adjoin absence as the identity of any Semigroup.

    Two present values combine left before right; a sole present value moves
    through unchanged. This is payload combination, not first-present fallback.

    Parameters:
        S: The present payloads' Semigroup, including its exact native error.
    """
    comptime Value = Optional[Self.S.Value]
    comptime Error = Self.S.Error
    @staticmethod
    def empty() -> Self.Value:
        """Return absence without invoking the Semigroup.

        Returns:
            An absent Optional.
        """
        return None
    @staticmethod
    def combine(var left: Self.Value, var right: Self.Value) raises Self.Error -> Self.Value:
        """Combine present values through the shared optional accumulator.

        Args:
            left: The earlier Optional, consumed.
            right: The later Optional, consumed.

        Returns:
            Absence, the sole present payload, or their ordered combination.

        Raises:
            The Semigroup's exact error, only when both are present.
        """
        if not right:
            return left^
        return _OptionalCombine[Self.S].combine(left^, right.unsafe_take())


struct DictMonoid[K: KeyElement & Deinitable, S: Semigroup](Monoid):
    """Union native dictionaries, combining duplicate values left before right.

    Keys and values move; neither requires Copyable. Right entries are visited
    in native iteration order. Key iteration order of the merged dictionary
    is not a monoid guarantee; laws compare key/value mappings. Expected cost
    is linear in right entries, plus combination costs and native table growth.

    Parameters:
        K: The native dictionary key type.
        S: The Semigroup for duplicate values.
    """
    comptime Value = Dict[Self.K, Self.S.Value]
    comptime Error = Self.S.Error
    @staticmethod
    def empty() -> Self.Value:
        """Construct an empty native dictionary.

        Returns:
            The union identity.
        """
        return Self.Value()
    @staticmethod
    def combine(var left: Self.Value, var right: Self.Value) raises Self.Error -> Self.Value:
        """Consume right entries into left, combining only duplicate keys.

        Args:
            left: The earlier dictionary, consumed and reused.
            right: The later dictionary, drained and consumed.

        Returns:
            The merged native dictionary with owned keys and values.

        Raises:
            The exact duplicate-value combination error. Partial output and
            remaining entries are destroyed; external effects are not rolled back.
        """
        for var entry in right.take_items():
            # DictEntry's consuming callback is the native boundary for moving
            # both fields; a field move cannot leave the entry usable for the
            # other field. Split through the shared owned-pair operation.
            var pair = MaybeUninit[Tuple[Self.K, Self.S.Value]]()
            def take(var key: Self.K, var value: Self.S.Value) {mut pair}:
                pair.unsafe_ptr().unsafe_write((key^, value^))
            entry^.deinit_with(take)
            var key_slot = MaybeUninit[Self.K]()
            var value_slot = MaybeUninit[Self.S.Value]()
            _take_pair(pair^.unsafe_assume_init(), key_slot, value_slot)
            var key = key_slot^.unsafe_assume_init()
            var value = value_slot^.unsafe_assume_init()
            if key in left:
                var earlier: Self.S.Value
                try:
                    earlier = left.pop(key)
                except:
                    abort("DictMonoid: key disappeared during exclusive merge")
                left[key^] = Self.S.combine(earlier^, value^)
            else:
                left[key^] = value^
        return left^
