# error: cannot implicitly convert
from fp.callables import MutableThunk
from fp.data import Capture, Result
struct Fails(MutableThunk):
    comptime Out = Int
    comptime Error = Int
    def __init__(out self): pass
    def call_mut(mut self) raises Int -> Int: raise 7
def wrong() -> Result[Int, String]:
    return Capture[String]().run(Fails())
def main(): pass
