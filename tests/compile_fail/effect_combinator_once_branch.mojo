# List branches run per element, so once thunks are rejected.
# error: no matching method in call to 'if_effect'
# error: violated constraint
from fp.functions import pipeline
from fp.callables import OnceThunk
@fieldwise_init
struct EFOnceBranch(OnceThunk):
    comptime Out = List[Int]
    def call_once(deinit self) -> Self.Out: return [1]
def main():
    var xs: List[Bool] = [True,False]
    _ = pipeline(xs^).if_effect(EFOnceBranch(),EFOnceBranch())
