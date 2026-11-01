# error: constraint
from fp.data import Ior, Right
from fp.algebra import map, IorFamily, StringMonoid
from fp.functions import Identity
def main():
    _ = map[IorFamily[StringMonoid]](Ior[Int, Int](Right(1)), Identity[Int]())
