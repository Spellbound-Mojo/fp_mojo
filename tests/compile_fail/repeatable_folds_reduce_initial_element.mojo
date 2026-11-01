# error: no matching function in call
from fp.iteration import reduce
from fp.callables import MutableBinary
from fp.data import ControlFlow,Continue
struct Step(MutableBinary):
    comptime First=Int
    comptime Second=String
    comptime Out=Int
    def __init__(out self):pass
    def call_mut(mut self,var a:Int,var b:String)->Self.Out: return a
def main() raises: _=reduce([1],Step(),initial=0)
