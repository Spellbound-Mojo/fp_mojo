# error: no matching method
from fp.functions import pipeline, kleisli
from fp.algebra import IdentityFamily, ListFamily
from fp.effects import ResultT
from fp.callables import OnceUnary

@fieldwise_init
struct Restore(OnceUnary):
    var value: Int
    comptime Arg = String
    comptime Out = Int
    def call_once(deinit self, var reason: String) -> Int: return self.value

def main():
    comptime Layer = ResultT[ListFamily, String]
    var handler = kleisli[IdentityFamily](Restore(1))
    _ = pipeline[Layer](Layer.fail[Int](String("bad"))).recover(handler^).get()
