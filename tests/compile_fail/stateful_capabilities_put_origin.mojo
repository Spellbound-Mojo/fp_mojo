# error: cannot be converted
from fp.effects import State, ReaderT, LiftStateful, put
def bad(left: List[Int], right: List[Int]):
    comptime S = State[Span[Int, origin_of(left)]]
    _ = put[LiftStateful[ReaderT[S, Int], S]](Span(right))
def main(): bad([1], [2])
