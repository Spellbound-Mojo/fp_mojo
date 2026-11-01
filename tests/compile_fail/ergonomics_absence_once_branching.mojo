# error: no matching
from fp.algebra import ListFamily, or_else_absent
from fp.callables import OnceThunk
@fieldwise_init
struct OnlyOnce(OnceThunk):
    comptime Out = List[Optional[Int]]
    def call_once(deinit self) -> Self.Out: return [Optional(2)]
def main(): _ = or_else_absent[ListFamily](OnlyOnce(), List[Optional[Int]]([None, None]))
