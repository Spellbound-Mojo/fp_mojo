# error: no matching method in call to 'tap_each'
from fp.callables import BorrowOnceCallable,BorrowMutableCallable,BorrowCallContract
from fp.functions import pipeline
struct Once(BorrowOnceCallable):
    comptime Payload=Int
    comptime Result=Int
    def __init__(out self):pass
    def invoke_once(deinit self,ref value:Int)->Int:return value
def main() raises:_=pipeline(List[Int]([1,2])).tap_each(Once())
