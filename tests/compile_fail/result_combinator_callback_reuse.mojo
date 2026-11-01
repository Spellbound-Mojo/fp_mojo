# error: use of uninitialized value
from fp.data import Result, Ok
from fp.callables import OnceThunk
@fieldwise_init
struct RCRejectedFactory(OnceThunk):
    var value: String
    comptime Out = Result[String, String]
    def call_once(deinit self) -> Self.Out: return Ok(self.value^)
def main():
    var factory = RCRejectedFactory("owned")
    _ = Result[Int, String](Ok(1)).before(factory^)
    _ = factory^
