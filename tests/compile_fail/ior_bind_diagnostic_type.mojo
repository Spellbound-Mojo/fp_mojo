# error: constraint
from fp.data import Ior, Right
from fp.algebra import flat_map, IorFamily, StringMonoid
def step(value: Int) -> Ior[Int, Int]: return Right(value)
def main():
    _ = flat_map[IorFamily[StringMonoid]](step, Ior[String, Int](Right(1)))
