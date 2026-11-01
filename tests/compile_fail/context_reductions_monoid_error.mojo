# error: no matching method
from fp.functions import pipeline
from fp.algebra import Monoid
struct M(Monoid):
    comptime Value=Int
    comptime Error=Int
    @staticmethod
    def empty() raises Int -> Int: return 0
    @staticmethod
    def combine(var a:Int,var b:Int) raises Int -> Int: return a+b
def bad(var value:Int) raises String -> Int: raise String("bad")
def main(): _ = pipeline(range(3)).raising[String]().fold_map[M](bad).get()
