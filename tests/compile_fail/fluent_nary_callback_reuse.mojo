from fp.functions import pipeline
# error: uninitialized
from fp.data import Result,Ok
from fp.callables import OnceUnary
@fieldwise_init
struct NaryOwner(OnceUnary):
    comptime Arg=Tuple[Int,Int]
    comptime Out=Int
    def call_once(deinit self,var arg:Self.Arg) -> Int: return arg[0]
def main():
    var f=NaryOwner()
    _=pipeline(Result[Int,String](Ok(1))).map_n((Result[Int,String](Ok(2)),),f^).get()
    _=f^
