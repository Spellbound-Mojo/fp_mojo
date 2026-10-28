# error: no matching method in call to 'pair_with'
from fp.callables import BorrowOnceCallable,BorrowMutableCallable,BorrowCallContract
from fp.functions import piped,pipeline
struct Wrong(BorrowMutableCallable):
    comptime Payload=String
    comptime Result=Int
    def __init__(out self):pass
    def invoke_mut(mut self,ref value:String)->Int:return 1
def main() raises:_=piped(List[Int]([1,2])).pair_with(Wrong())
