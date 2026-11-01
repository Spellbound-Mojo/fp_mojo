"""Native map wrappers forward repeatable receiver evidence without private types."""
from fp.algebra import ArrayFamily, Functor
from fp.algebra.contracts import MapContract
from fp.callables import UnaryContract, RepeatableUnary
from fp.functions import Pipeline, pipeline, pipeline_values
from std.collections import Array, KeyElement
from std.hash import Hasher
from std.testing import assert_equal
from test_container_map import ContainerMapCounter


# The family is a parameter: on Mojo 1.2 a where clause naming ArrayFamily[N]
# with symbolic N does not supply evidence for Pipeline.map's admission.
def array_map[I: Functor, N: Int, F: UnaryContract & Movable & Deinitable](
    var function: F, var values: Array[F.Arg, N]
) raises MapContract[I, Array[F.Arg, N], F].Error -> MapContract[I, Array[F.Arg, N], F].Out where RepeatableUnary[F] and MapContract[I, Array[F.Arg, N], F].Compatible:
    return pipeline[I](values^).map(function^).get()


# Dict values have no public family name: the wrapper receives the selected
# Pipeline from pipeline_values and forwards that family generically.
def dict_map[I: Functor, K: KeyElement & Deinitable, H: Hasher & Defaultable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var function: F, var values: Pipeline[I, Dict[K, F.Arg, H]]
) raises MapContract[I, Dict[K, F.Arg, H], F].Error -> MapContract[I, Dict[K, F.Arg, H], F].Out where RepeatableUnary[F] and MapContract[I, Dict[K, F.Arg, H], F].Compatible:
    return values^.map(function^).get()


def main() raises:
    var values: Array[Int, 2] = [1, 2]
    var mapped = array_map[ArrayFamily[2]](ContainerMapCounter(0), values^)
    assert_equal(mapped[0], 2)
    assert_equal(mapped[1], 4)
    var dictionary = Dict[String, Int]()
    dictionary["first"] = 7
    dictionary["second"] = 9
    var results = dict_map(ContainerMapCounter(0), pipeline_values(dictionary^))
    assert_equal(results["first"], 8)
    assert_equal(results["second"], 11)
