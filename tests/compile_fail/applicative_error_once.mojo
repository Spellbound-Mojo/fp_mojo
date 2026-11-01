# ResultT over ListFamily applies recovery per element, so a once handler is rejected.
# error: no matching method in call to 'recover'
# error: violated constraint
from fp.algebra import ResultFamily, ListFamily, fail
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from fp.effects import ResultT
from fp.callables import OnceUnary
@fieldwise_init
struct AEOnce(OnceUnary, Defaultable):
    comptime Arg = String
    comptime Out = Int
    def call_once(deinit self, var error: String) -> Int: return 1
def main():
    comptime F = ResultT[ListFamily, String]
    _ = pipeline[F](fail[F, Int](String("bad"))).recover(AEOnce()).get()
