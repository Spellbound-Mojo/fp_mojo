# error: no matching method in call to 'tap'
from fp.callables import BorrowOnceCallable,BorrowMutableCallable,BorrowCallContract
from fp.functions import pipeline
struct Wrong(BorrowMutableCallable):
    comptime Payload=String
    comptime Result=Int
    def __init__(out self):pass
    def invoke_mut(mut self,ref value:String)->Int:return 1
def main() raises:_=pipeline(7).tap(Wrong())
