# error: use of uninitialized value
from fp.data import Result, Err
from fp.callables import OnceUnary
@fieldwise_init
struct RSRejectedRecovery(OnceUnary):
    var value: String
    comptime Arg = String
    comptime Out = String
    def call_once(deinit self, var error: String) -> String: return self.value^
def predicate(error: String) -> Bool: return False
def main():
    var recovery = RSRejectedRecovery("owned")
    _ = Result[String, String](Err(String("skip"))).recover_if(predicate, recovery^)
    _ = recovery^
