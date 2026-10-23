# error: Monad
from fp.data import Ior, Right
from fp.algebra import flat_map, IorValidationFamily, StringMonoid
def step(value: Int) -> Ior[String, Int]: return Right(value)
def main():
    _ = flat_map[IorValidationFamily[StringMonoid]](step, Ior[String, Int](Right(1)))
