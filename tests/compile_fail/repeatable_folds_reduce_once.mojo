# error: no matching function in call
from fp.iteration import reduce
from fp.callables import OnceBinary
from fp.data import ControlFlow,Continue
struct Step(OnceBinary):
    comptime First=Int
    comptime Second=Int
    comptime Out=Int
    def __init__(out self):pass
    def call_once(deinit self,var a:Int,var b:Int)->Self.Out: return a
def main() raises: _=reduce([1],Step())
