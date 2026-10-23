# error: constraint
from fp.data import Ior, Right
from fp.algebra import map, IorFamily, StringMonoid
from fp.functions import Identity
def main():
    _ = map[IorFamily[StringMonoid]](Identity[Int](), Ior[Int, Int](Right(1)))
