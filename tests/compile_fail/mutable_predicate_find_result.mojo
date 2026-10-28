# error: no matching method in call to 'find'
from fp.callables import BorrowMutableCallable
from fp.iteration import iterated
struct Step(BorrowMutableCallable):
    comptime Payload=Int
    comptime Result=Int
    def __init__(out self):pass
    def invoke_mut(mut self,ref value:Int)->Int:return 1
def main() raises:_=iterated(range(3)).find(Step())
