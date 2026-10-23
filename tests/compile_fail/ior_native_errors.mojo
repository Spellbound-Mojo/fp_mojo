# error: constraint
from fp.data import Ior, Both
from fp.algebra import IorFamily, Semigroup, flat_map
struct IORPolicy(Semigroup):
    comptime Value = String
    comptime Error = String
    @staticmethod
    def combine(var left: String, var right: String) raises String -> String: raise left^
def step(value: Int) raises Int -> Ior[String, Int]: return Both(String("b"), value)
def main() raises String:
    _ = flat_map[IorFamily[IORPolicy]](step, Ior[String, Int](Both(String("a"), 1)))
