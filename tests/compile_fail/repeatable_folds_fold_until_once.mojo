# error: no matching function in call
from fp.iteration import fold_until
from fp.callables import OnceBinary
from fp.data import ControlFlow,Continue
struct Step(OnceBinary):
    comptime First=Int
    comptime Second=Int
    comptime Out=ControlFlow[Int,Int]
    def __init__(out self):pass
    def call_once(deinit self,var a:Int,var b:Int)->Self.Out: return Self.Out(Continue(a))
def main() raises: _=fold_until([1],0,Step())
