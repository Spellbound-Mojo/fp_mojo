# error: exact non-raising unary callable required
from fp.iteration import iterated
from fp.callables import OnceThunk
@fieldwise_init
struct SeqFactory(OnceThunk, Defaultable):
    comptime Out = List[Int]
    def call_once(deinit self) -> Self.Out: return List[Int]([1])
def main():
    _ = iterated(range(2)).followed_by(SeqFactory()).to_list()
