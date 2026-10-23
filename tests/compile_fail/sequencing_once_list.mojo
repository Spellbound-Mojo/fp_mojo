# error: repeatable
from fp.functions import piped
from fp.callables import OnceThunk
@fieldwise_init
struct SeqFactory(OnceThunk, Defaultable):
    comptime Out = List[Int]
    def call_once(deinit self) -> Self.Out: return List[Int]([1])
def main():
    _ = piped(List[Int]([1,2])).before(SeqFactory()).get()
