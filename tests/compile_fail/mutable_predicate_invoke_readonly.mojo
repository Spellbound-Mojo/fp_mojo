# error: must be mutable
from fp.callables import BorrowMutableCallable,invoke_borrowed_repeated
@fieldwise_init
struct Step(BorrowMutableCallable):
    comptime Payload=Int
    comptime Result=Bool
    var calls:Int
    def invoke_mut(mut self,ref value:Int)->Bool:return True
def wrong(callback:Step,value:Int):_=invoke_borrowed_repeated[Never](value,callback)
def main():pass
