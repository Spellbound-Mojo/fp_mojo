# error: use of uninitialized value
from fp.data import Result, Ok
from fp.callables import OnceUnary
@fieldwise_init
struct RORejectedCallback(OnceUnary):
    var value: String
    comptime Arg = String
    comptime Out = String
    def call_once(deinit self, var payload: String) -> String: return self.value^
def on_ok(value: Int) -> String: return String(value)
def main():
    var handler = RORejectedCallback("unused")
    _ = Result[Int, String](Ok(1)).redeem(on_ok, handler^)
    _ = handler^
