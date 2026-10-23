# error: violated constraint
from fp.iteration import iterated
from fp.callables import OnceBinary
@fieldwise_init
struct I5Once(OnceBinary):
    comptime First=Int
    comptime Second=Int
    comptime Out=Tuple[Int,Int]
    def call_once(deinit self,var a:Int,var b:Int)->Self.Out: return (a+b,b)
def main(): _=iterated(range(3)).scan_map(I5Once(),0)
