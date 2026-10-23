# error: repeatable
from fp.functions import piped
from fp.callables import OnceUnary
@fieldwise_init
struct NaryOnce(OnceUnary):
    comptime Arg=Tuple[Int,Int,Int]
    comptime Out=Int
    def call_once(deinit self,var arg:Self.Arg) -> Int: return arg[0]
def main():
    var a:List[Int]=[1]
    var b:List[Int]=[2]
    var c:List[Int]=[3]
    _=piped(a^).map_n((b^,c^),NaryOnce())
