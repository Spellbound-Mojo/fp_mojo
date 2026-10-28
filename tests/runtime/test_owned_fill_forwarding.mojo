"""Native map wrappers forward repeatable receiver evidence without private types."""
from fp.callables import UnaryContract, RepeatableUnary
from fp.functions import piped
from std.collections import Array, KeyElement
from std.hash import Hasher
from std.testing import assert_equal
from test_container_map import ContainerMapCounter


def array_map[N: Int, F: UnaryContract & Movable & Deinitable](
    var function: F, var values: Array[F.Arg, N]
) raises F.Error -> Array[F.Out, N] where RepeatableUnary[F]:
    return piped(values^).map(function^).get()


def dict_map[K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var function: F, var values: Dict[K, F.Arg, H]
) raises F.Error -> Dict[K, F.Out, H] where RepeatableUnary[F]:
    return piped(values^).map(function^).get()


def main() raises:
    var values: Array[Int, 2] = [1, 2]
    var mapped = array_map(ContainerMapCounter(0), values^)
    assert_equal(mapped[0], 2)
    assert_equal(mapped[1], 4)
    var dictionary = Dict[String, Int]()
    dictionary["first"] = 7
    dictionary["second"] = 9
    var results = dict_map(ContainerMapCounter(0), dictionary^)
    assert_equal(results["first"], 8)
    assert_equal(results["second"], 11)
