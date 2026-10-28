# error: no matching function in call
from fp.iteration import reduce_optional
from fp.callables import MutableBinary
from fp.data import ControlFlow,Continue
struct Step(MutableBinary):
    comptime First=Int
    comptime Second=Int
    comptime Out=String
    def __init__(out self):pass
    def call_mut(mut self,var a:Int,var b:Int)->Self.Out: return String("wrong")
def main() raises: _=reduce_optional(Step(),[1])
