# error: List callbacks must be repeatable
from fp.functions import piped
from fp.callables import OnceThunk
@fieldwise_init
struct EFOnceBranch(OnceThunk):
    comptime Out = List[Int]
    def call_once(deinit self) -> Self.Out: return [1]
def main():
    var xs: List[Bool] = [True,False]
    _ = piped(xs^).if_effect(EFOnceBranch(),EFOnceBranch())
