# error: no matching method in call to 'before'
from fp.functions import pipeline
from fp.callables import OnceThunk
@fieldwise_init
struct SeqFactory(OnceThunk, Defaultable):
    comptime Out = List[Int]
    def call_once(deinit self) -> Self.Out: return List[Int]([1])
def main():
    _ = pipeline(List[Int]([1,2])).before(SeqFactory()).get()
