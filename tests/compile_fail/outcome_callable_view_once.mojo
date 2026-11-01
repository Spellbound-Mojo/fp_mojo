# error: no matching method in call to 'redeem'
from fp.functions import pipeline, kleisli
from fp.algebra import IdentityFamily, ListFamily
from fp.effects import ResultT
from fp.callables import OnceUnary

@fieldwise_init
struct Handler(OnceUnary):
    comptime Arg = String
    comptime Out = Int
    def call_once(deinit self, var value: String) -> Int: return 1

def success(value: Int) -> Int: return value

def main():
    var on_ok = kleisli[IdentityFamily](success)
    var on_err = kleisli[IdentityFamily](Handler())
    comptime I = ResultT[ListFamily, String]
    _ = pipeline[I](I.pure(1)).redeem(on_ok, on_err^).get()
