# error: constraint failed: collect_fold: callback and monoid error types must match
from fp.functions import partial
from fp.iteration import collect_fold
from fp.algebra import Monoid
struct M(Monoid):
    comptime Value = Int
    comptime Error = Int
    @staticmethod
    def empty() raises Int -> Int: return 0
    @staticmethod
    def combine(var left: Int, var right: Int) raises Int -> Int: return left + right
def fail(offset: Int, value: Int) raises String -> Optional[Int]: raise String(offset + value)
def main():
    var project = partial(fail, 1)
    try: _ = collect_fold[M](range(3), project)
    except: pass
