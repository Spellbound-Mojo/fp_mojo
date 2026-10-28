# error: no matching function in call to 'take_while'
from fp.callables import BorrowOnceCallable
from fp.iteration import take_while, Unbounded
struct Step(BorrowOnceCallable):
    comptime Payload=Int
    comptime Result=Bool
    def __init__(out self):pass
    def invoke_once(deinit self,ref value:Int)->Bool:return True
def main() raises:_=take_while(Step(),range(3))
