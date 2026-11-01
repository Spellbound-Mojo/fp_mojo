# error: no matching method in call to 'find'
from fp.callables import BorrowMutableCallable
from fp.iteration import iterated
struct Step(BorrowMutableCallable):
    comptime Payload=String
    comptime Result=Bool
    def __init__(out self):pass
    def invoke_mut(mut self,ref value:String)->Bool:return True
def main() raises:_=iterated(range(3)).find(Step())
