# error: invalid call to 'map_err': lacking evidence to prove correctness
from fp.algebra import ResultFamily
from fp.effects import ReaderT
from fp.functions import pipeline
def wrong(left: List[Int], right: List[Int]):
    comptime L = type_of(Span(left))
    comptime R = type_of(Span(right))
    comptime I = ReaderT[ResultFamily[L],Int]
    comptime T = ReaderT[ResultFamily[L],Int]
    def replace(var error: L) {ref right} -> R: return Span(right)
    _ = pipeline[I](I.fail[Int](Span(left))).map_err[Target=T](replace)
def main():
    wrong(List[Int]([1]),List[Int]([2]))
