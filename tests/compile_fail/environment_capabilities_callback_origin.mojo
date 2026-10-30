# error: constraint
from fp.effects import Reader, StateT, LiftLocal, ask, local
def bad(left: List[Int], right: List[Int]):
    comptime L = Span[Int, origin_of(left)]
    comptime R = Span[Int, origin_of(right)]
    comptime C = LiftLocal[StateT[Reader[L], Int], Reader[L]]
    def wrong(value: R) -> R: return value
    _ = local[C](ask[C](), wrong)
def main(): bad([1], [2])
