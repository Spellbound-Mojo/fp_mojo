# error: no matching function in call to 'filter_not'
from fp.callables import BorrowMutableCallable
from fp.iteration import filter_not, Unbounded
struct Step(BorrowMutableCallable):
    comptime Payload=Int
    comptime Result=Bool
    comptime Failure=Int
    def __init__(out self):pass
    def invoke_mut(mut self,ref value:Int) raises Int->Bool:return True
def main() raises:_=filter_not(range(3),Step())
