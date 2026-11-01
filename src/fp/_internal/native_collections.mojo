"""Version-specific native collection storage conversions, without callbacks.

Qualified against Mojo 1.2.0 (2016d0cd), modular/modular revision
527d069ee11a41ac5320af1f9402db0a66b2b868 (Mojo/stdlib/std/collections).
Deque has no public configuration getters. StringDict.deinit_with moves entries
but cannot transfer its backing Dict intact. Keep all private field accesses
here until equivalent public operations preserve ownership, order and cost.
"""
from std.collections import Deque, StringDict
from std.hash import default_comp_time_hasher


def _empty_deque_like[T: Movable & Deinitable, U: Movable & Deinitable](
    source: Deque[T]
) -> Deque[U]:
    # The public constructor retains bounded eviction and shrink policy.
    return Deque[U](capacity=source._capacity, min_capacity=source._min_capacity,
                    maxlen=source._maxlen, shrink=source._shrink)


def _take_string_dict[T: Movable & Deinitable](
    var source: StringDict[T]
) -> Dict[String, T, default_comp_time_hasher]:
    # Reinitialize the moved field before destruction; no entry is copied.
    var native = source._dict^
    source._dict = Dict[String, T, default_comp_time_hasher]()
    return native^


def _string_dict_from_native[T: Movable & Deinitable](
    var native: Dict[String, T, default_comp_time_hasher]
) -> StringDict[T]:
    var result = StringDict[T]()
    result._dict = native^
    return result^
