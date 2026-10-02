"""Positional partial application of native functions: counts, conventions,
exact errors, fixed-arity views and library integration."""
from std.iter import iter
from std.testing import assert_equal, assert_true, assert_false
from fp.functions import partial, Partial
from fp.callables import Thunk, Unary, Binary
from fp.algebra import map, map2, flat_map, OptionalFamily, ListFamily, IdentityFamily
from fp.iteration import (map as lazy_map, filter_map, flat_map as lazy_flat_map, scan_left,
    fold_left, reduce, reduce_optional, fold_until, collect_list)
from fp.data import Break, Continue, ControlFlow


def weighted(a: Int, b: Int, c: Int, d: Int, e: Int, f: Int, g: Int, h: Int, i: Int) -> Int:
    return a + 2 * b + 3 * c + 4 * d + 5 * e + 6 * f + 7 * g + 8 * h + 9 * i


def twice(var x: Int) -> Int:
    return x * 2


def double(x: Int) -> Int:
    return x * 2


def add(a: Int, b: Int) -> Int:
    return a + b


def add3(a: Int, b: Int, c: Int) -> Int:
    return a * 100 + b * 10 + c


def greet(prefix: String, name: String) -> String:
    return prefix + name


def label(var tag: String, n: Int) -> String:
    return tag + String(n)


def append_to(var values: List[Int], extra: List[Int]) -> List[Int]:
    values.extend(extra.copy())
    return values^


@fieldwise_init
struct Token(Movable):
    var value: Int


def unwrap(offset: Int, token: Token) -> Int:
    return offset + token.value


@fieldwise_init
struct Rejected(Movable):
    var value: Int


def checked(limit: Int, x: Int) raises Rejected -> Int:
    if x > limit:
        raise Rejected(x)
    return x


def capped(limit: Int, total: Int, x: Int) raises Rejected -> Int:
    if total + x > limit:
        raise Rejected(total + x)
    return total + x


def keep_above(limit: Int, x: Int) -> Optional[Int]:
    return Optional(x) if x > limit else Optional[Int]()


def repeat(times: Int, x: Int) -> List[Int]:
    var out = List[Int]()
    for _ in range(times):
        out.append(x)
    return out^


def until(limit: Int, total: Int, x: Int) -> ControlFlow[Int, Int]:
    if total + x > limit:
        return ControlFlow[Int, Int](Break(total))
    return ControlFlow[Int, Int](Continue(total + x))


def pure_caller() -> Int:
    # A non-raising target gives a non-raising partial.
    return partial(add, 1)(2)


def every_count() raises:
    var total = 45
    assert_equal(partial(weighted)(1, 1, 1, 1, 1, 1, 1, 1, 1), total)
    assert_equal(partial(weighted, 1)(1, 1, 1, 1, 1, 1, 1, 1), total)
    assert_equal(partial(weighted, 1, 1)(1, 1, 1, 1, 1, 1, 1), total)
    assert_equal(partial(weighted, 1, 1, 1)(1, 1, 1, 1, 1, 1), total)
    assert_equal(partial(weighted, 1, 1, 1, 1)(1, 1, 1, 1, 1), total)
    assert_equal(partial(weighted, 1, 1, 1, 1, 1)(1, 1, 1, 1), total)
    assert_equal(partial(weighted, 1, 1, 1, 1, 1, 1)(1, 1, 1), total)
    assert_equal(partial(weighted, 1, 1, 1, 1, 1, 1, 1)(1, 1), total)
    assert_equal(partial(weighted, 1, 1, 1, 1, 1, 1, 1, 1)(1), total)
    # Order: bound arguments first, then the call-time ones.
    assert_equal(partial(weighted, 1, 0, 0, 0, 0, 0, 0, 0)(0), 1)
    assert_equal(partial(weighted, 0, 0, 0, 0, 0, 0, 0, 0)(1), 9)


def conventions() raises:
    var value = 4
    var doubled = partial(twice, value)
    assert_equal(doubled(), 8)
    assert_equal(doubled(), 8)
    assert_equal(value, 4)
    assert_equal(partial(add3, 1)(2, 3), 123)
    assert_equal(partial(add3, 1, 2)(3), 123)
    assert_equal(partial(add3, 1, 2, 3)(), 123)
    # Bound parameters may be read or owned; remaining arguments are borrowed.
    var prefix = String("hi ")
    var hello = partial(greet, prefix)
    var name = String("ann")
    assert_equal(hello(name), "hi ann")
    assert_equal(name, "ann")
    prefix = String("changed ")
    assert_equal(hello(String("bo")), "hi bo")
    assert_equal(prefix, "changed ")
    assert_equal(partial(label, String("n="))(5), "n=5")
    var base: List[Int] = [1, 2]
    var extended = partial(append_to, base)
    assert_equal(extended([3]), [1, 2, 3])
    assert_equal(extended([4]), [1, 2, 4])
    assert_equal(base, [1, 2])
    # A move-only remaining argument can be read by the target.
    assert_equal(partial(unwrap, 10)(Token(5)), 15)
    # A partial is an ordinary copyable value.
    var copied = hello.copy()
    assert_equal(copied(String("cy")), "hi cy")
    assert_equal(pure_caller(), 3)


def errors() raises:
    var small = partial(checked, 10)
    var results = List[Int]()
    for x in [3, 30, 4]:
        try:
            results.append(small(x))
        except error:
            comptime assert type_of(error) == Rejected
            results.append(-error.value)
    assert_equal(results, [3, -30, 4])


def fixed_arity_views() raises:
    comptime assert conforms_to(type_of(partial(add, 1, 2)), Thunk)
    comptime assert conforms_to(type_of(partial(add, 1)), Unary)
    comptime assert not conforms_to(type_of(partial(add, 1)), Binary)
    comptime assert conforms_to(type_of(partial(add)), Binary)
    comptime assert not conforms_to(type_of(partial(add3)), Unary)
    assert_equal(partial(add, 1, 2).call(), 3)
    assert_equal(partial(add, 1).call(2), 3)
    assert_equal(partial(add).call(1, 2), 3)
    comptime assert type_of(partial(add, 1)) == Partial[Int, Never, TypeList.of[Trait=Copyable & Deinitable, Int](), TypeList.of[Trait=Movable, Int]()]


def algebra() raises:
    assert_equal(map[OptionalFamily](partial(add, 10), Optional(5)).value(), 15)
    assert_equal(map[IdentityFamily](partial(double), 21), 42)
    var values: List[Int] = [1, 2, 3]
    assert_equal(map[ListFamily](partial(add3, 1, 2), values^), [121, 122, 123])
    assert_equal(map2[OptionalFamily](partial(add), Optional(1), Optional(2)).value(), 3)
    assert_false(Bool(flat_map[OptionalFamily](partial(keep_above, 5), Optional(3))))


def iteration() raises:
    var xs: List[Int] = [1, 2, 3]
    assert_equal(collect_list(lazy_map(partial(add, 10), iter(xs))), [11, 12, 13])
    assert_equal(collect_list(filter_map[Int](partial(keep_above, 1), iter(xs))), [2, 3])
    assert_equal(collect_list(lazy_flat_map(partial(repeat, 2), iter(xs))), [1, 1, 2, 2, 3, 3])
    assert_equal(collect_list(scan_left(partial(add3, 0), 0, iter(xs))), [0, 1, 12, 123])
    assert_equal(fold_left(partial(add3, 0), 0, iter(xs)), 123)
    assert_equal(reduce(partial(add), iter(xs)), 6)
    assert_equal(reduce(partial(add), iter(xs), initial=100), 106)
    assert_equal(reduce_optional(partial(add), iter(xs)).value(), 6)
    var empty = List[Int]()
    assert_false(Bool(reduce_optional(partial(add), iter(empty))))
    var stopped = fold_until[Int](partial(until, 4), 0, iter(xs))
    assert_true(stopped.isa[Break[Int]]())
    assert_equal(stopped[Break[Int]].value, 3)
    var failed = False
    try:
        _ = fold_left(partial(capped, 4), 0, iter(xs))
    except error:
        comptime assert type_of(error) == Rejected
        failed = True
        assert_equal(error.value, 6)
    assert_true(failed)


def main() raises:
    every_count()
    conventions()
    errors()
    fixed_arity_views()
    algebra()
    iteration()
    print("partial: ok")
