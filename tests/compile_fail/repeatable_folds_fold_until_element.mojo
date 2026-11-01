# error: no matching function in call
from fp.iteration import fold_until
from fp.callables import MutableBinary
from fp.data import ControlFlow,Continue
struct Step(MutableBinary):
    comptime First=Int
    comptime Second=String
    comptime Out=ControlFlow[Int,Int]
    def __init__(out self):pass
    def call_mut(mut self,var a:Int,var b:String)->Self.Out: return Self.Out(Continue(a))
def main() raises: _=fold_until([1],0,Step())
