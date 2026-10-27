# error: use of uninitialized value
from fp.data import Result, Err
from fp.callables import OnceThunk
@fieldwise_init
struct Default(OnceThunk):
    var value: String
    comptime Out = String
    def call_once(deinit self) -> String: return self.value^
def main():
    var callback = Default("fallback")
    var source = Result[String, Int](Err(0))
    _ = source^.get_or_else(callback^)
    _ = callback^.call_once()
