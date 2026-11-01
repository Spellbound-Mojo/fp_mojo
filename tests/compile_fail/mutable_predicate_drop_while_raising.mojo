# error: no matching function in call to 'drop_while'
from fp.callables import BorrowMutableCallable
from fp.iteration import drop_while, Unbounded
struct Step(BorrowMutableCallable):
    comptime Payload=Int
    comptime Result=Bool
    comptime Failure=Int
    def __init__(out self):pass
    def invoke_mut(mut self,ref value:Int) raises Int->Bool:return True
def main() raises:_=drop_while(range(3),Step())
