# error: uninitialized
from fp.algebra import ResultFamily, ListFamily, fail
from fp.functions import piped
from fp.data import Result, Ok, Err
from fp.callables import OnceUnary
@fieldwise_init
struct AEOnce(OnceUnary):
    var captured: String
    comptime Arg = String
    comptime Out = Int
    def call_once(deinit self, var error: String) -> Int: return self.captured.byte_length()
def main():
    var handler = AEOnce(String("capture"))
    _ = piped(fail[ResultFamily[String], Int](String("bad"))).recover[ResultFamily[String]](handler^).get()
    _ = handler^.call_once(String())
