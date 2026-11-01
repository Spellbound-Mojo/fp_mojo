"""Derived operations retain exact contracts when forwarding generic callbacks."""
from std.builtin.rebind import rebind_var
from std.testing import assert_equal
from fp.functions import pipeline
from fp.iteration import iterated
from fp.algebra import ListFamily


def expansion_forward_select[T: Movable & Deinitable, U: Movable & Deinitable, //,
                             F: def(var T) -> Optional[U]](ref function: F, var values: List[T]) -> List[U]:
    return pipeline[ListFamily](values^).filter_map(function).get()


def expansion_forward_raised[T: Movable & Deinitable, U: Movable & Deinitable, E: Movable & Deinitable, //,
                             F: def(var T) raises E -> Optional[U]](ref function: F, var values: List[T]) raises E -> List[U]:
    return pipeline[ListFamily](values^).raising[E]().filter_map(function).get()


def expansion_forward_pair[T: Movable & Deinitable, U: Movable & Deinitable, //,
                           F: def(T) -> U](ref function: F, var values: List[T]) -> List[Tuple[T, U]]:
    return pipeline[ListFamily](values^).pair_with(function).get()


def expansion_forward_min[T: Movable & Deinitable, K: Comparable & Movable & Deinitable, E: Movable & Deinitable, //,
                          F: def(T) raises E -> K](ref function: F, var values: List[T]) raises E -> Optional[T]:
    return iterated(values^).min_by[E=E](function)


def expansion_forward_sum[T: Movable & Deinitable, E: Movable & Deinitable, //,
                          F: def(var T) raises E -> Int](ref function: F, var values: List[T]) raises E -> Int:
    return pipeline(values^).raising[E]().sum_by(function).get()


@fieldwise_init
struct ExpansionGenericFailure(Movable):
    var code: Int

def expansion_generic_some(x: Int) -> Optional[Int]: return Optional(x * 2)
def expansion_generic_checked(x: Int) raises ExpansionGenericFailure -> Optional[Int]:
    if x == 2: raise ExpansionGenericFailure(2)
    return Optional(x)
def expansion_generic_square(x: Int) -> Int: return x * x
def expansion_generic_key(x: Int) raises ExpansionGenericFailure -> Int:
    if x < 0: raise ExpansionGenericFailure(x)
    return x

def expansion_generic_origins(anchor: List[Int]) raises:
    def expansion_generic_view(x: Int) {anchor} -> Span[Int, origin_of(anchor)]: return Span(anchor)
    var pairs = expansion_forward_pair(expansion_generic_view, List[Int]([1, 2]))
    assert_equal(pairs[0][1][0], 11)
    def expansion_generic_optional(x: Int) {anchor} -> Optional[Span[Int, origin_of(anchor)]]:
        return Optional(Span(anchor))
    var views = expansion_forward_select(expansion_generic_optional, List[Int]([1, 2]))
    assert_equal(views[1][1], 12)

def main() raises:
    assert_equal(expansion_forward_select(expansion_generic_some, List[Int]([1, 2])), [2, 4])
    assert_equal(expansion_forward_pair(expansion_generic_square, List[Int]([1, 2])), [(1, 1), (2, 4)])
    var total: Int
    var minimum: Optional[Int]
    try:
        total = expansion_forward_sum(expansion_generic_key, List[Int]([1, 2]))
        minimum = expansion_forward_min(expansion_generic_key, List[Int]([2, 1]))
    except:
        raise Error('unexpected callback failure')
    assert_equal(total, 3)
    assert_equal(minimum.value(), 1)
    var failed = False
    try: _ = expansion_forward_raised(expansion_generic_checked, List[Int]([1, 2]))
    except error:
        comptime assert type_of(error) == ExpansionGenericFailure
        assert_equal(error.code, 2)
        failed = True
    assert_equal(failed, True)
    expansion_generic_origins([11, 12])
