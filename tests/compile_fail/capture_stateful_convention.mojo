# error: no matching method
from fp.data import Capture
@fieldwise_init
struct Fault(Movable):
    var code:Int
@fieldwise_init
struct Other(Movable):
    var code:Int
@fieldwise_init
struct Token(Movable):
    var value:Int
def bad(var state:Token,var arg:String) raises Fault->Int:return 0
def main():
    _=Capture[Fault]().stateful(bad,Token(1))
