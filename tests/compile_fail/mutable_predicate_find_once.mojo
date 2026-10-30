# error: no matching function in call to 'find'
from fp.callables import BorrowOnceCallable
from fp.iteration import find, Unbounded
struct Step(BorrowOnceCallable):
    comptime Payload=Int
    comptime Result=Bool
    def __init__(out self):pass
    def invoke_once(deinit self,ref value:Int)->Bool:return True
def main() raises:_=find(range(3),Step())
