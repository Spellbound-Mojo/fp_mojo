# error: no matching function in call to 'drop_while'
from fp.callables import BorrowOnceCallable
from fp.iteration import drop_while, Unbounded
struct Step(BorrowOnceCallable):
    comptime Payload=Int
    comptime Result=Bool
    def __init__(out self):pass
    def invoke_once(deinit self,ref value:Int)->Bool:return True
def main() raises:_=drop_while(Step(),range(3))
