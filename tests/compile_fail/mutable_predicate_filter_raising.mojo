# error: no matching function in call to 'filter'
from fp.callables import BorrowMutableCallable
from fp.iteration import filter, Unbounded
struct Step(BorrowMutableCallable):
    comptime Payload=Int
    comptime Result=Bool
    comptime Failure=Int
    def __init__(out self):pass
    def invoke_mut(mut self,ref value:Int) raises Int->Bool:return True
def main() raises:_=filter(Step(),range(3))
