# error: no matching method in call
from fp.iteration import fold_left, iterated
from fp.callables import OnceBinary
from fp.data import ControlFlow,Continue
struct Step(OnceBinary):
    comptime First=Int
    comptime Second=Int
    comptime Out=Int
    def __init__(out self):pass
    def call_once(deinit self,var a:Int,var b:Int)->Self.Out: return a
def main() raises: _=iterated([1]).fold_left(Step(),0)
