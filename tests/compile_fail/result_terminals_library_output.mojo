# error: no matching method in call to 'get_or_else'
from fp.data import Result, Err
from fp.callables import OnceThunk
@fieldwise_init
struct Wrong(OnceThunk):
    comptime Out = String
    def call_once(deinit self) -> String: return "wrong"
def main():
    _ = Result[Int, String](Err(String("missing"))).get_or_else(Wrong())
