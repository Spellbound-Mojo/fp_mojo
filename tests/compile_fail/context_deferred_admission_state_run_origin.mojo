# error: invalid call to 'run': lacking evidence to prove correctness
# error: RunCompatible
# error: origin_of(left)
# error: origin_of(right)
from fp.effects import StateT, StateAction, run
from fp.algebra import ResultFamily
from fp.data import Result, Err

@fieldwise_init
struct Wrong[expected: ImmOrigin, actual: ImmOrigin](StateAction):
    var error: Span[Int, Self.actual]
    comptime Family = StateT[ResultFamily[Span[Int, Self.expected]], Int]
    comptime State = Int
    comptime Value = Int
    comptime Out = Result[Tuple[Int, Int], Span[Int, Self.actual]]
    def run(deinit self, var state: Int) -> Self.Out:
        return Err(self.error)

def check(left: List[Int], right: List[Int]):
    comptime I = StateT[ResultFamily[Span[Int, origin_of(left)]], Int]
    var wrong = Wrong[origin_of(left), origin_of(right)](Span(right))
    _ = run[I](wrong^, 0)

def main():
    var left = List[Int]([1])
    var right = List[Int]([2])
    check(left, right)
