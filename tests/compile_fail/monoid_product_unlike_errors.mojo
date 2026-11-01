# error: ProductMonoid: incompatible component errors
from fp.algebra import Monoid, ProductMonoid

struct FirstErrorMonoid(Monoid):
    comptime Value = Int
    comptime Error = Int
    @staticmethod
    def empty() raises Int -> Int: return 0
    @staticmethod
    def combine(var left: Int, var right: Int) raises Int -> Int: return left + right

struct SecondErrorMonoid(Monoid):
    comptime Value = Int
    comptime Error = String
    @staticmethod
    def empty() raises String -> Int: return 0
    @staticmethod
    def combine(var left: Int, var right: Int) raises String -> Int: return left + right

def main():
    try:
        _ = ProductMonoid[FirstErrorMonoid, SecondErrorMonoid].empty()
    except:
        pass
