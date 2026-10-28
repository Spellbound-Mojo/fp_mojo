# error: constraint failed: fold_map: callback and monoid error types must match
from fp.functions import partial
from fp.iteration import fold_map
from fp.algebra import Monoid
struct M(Monoid):
    comptime Value = Int
    comptime Error = Int
    @staticmethod
    def empty() raises Int -> Int: return 0
    @staticmethod
    def combine(var left: Int, var right: Int) raises Int -> Int: return left + right
def fail(offset: Int, value: Int) raises String -> Int: raise String(value + offset)
def main():
    var project = partial(fail, 1)
    try: _ = fold_map[M](project, range(3))
    except: pass
