# error: violated constraint
from fp.callables import BorrowOnceCallable,invoke_borrowed_repeated
from fp.iteration import filter, Unbounded
struct Step(BorrowOnceCallable):
    comptime Payload=Int
    comptime Result=Bool
    def __init__(out self):pass
    def invoke_once(deinit self,ref value:Int)->Bool:return True
def main():
    var value=1
    var callback=Step()
    _=invoke_borrowed_repeated[Never](value,callback)
