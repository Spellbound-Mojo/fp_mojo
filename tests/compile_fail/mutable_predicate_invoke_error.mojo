# error: violated constraint
from fp.callables import BorrowMutableCallable,invoke_borrowed_repeated
@fieldwise_init
struct Step(BorrowMutableCallable):
    comptime Payload=Int
    comptime Result=Bool
    comptime Failure=Int
    var calls:Int
    def invoke_mut(mut self,ref value:Int) raises Int->Bool:return True
def main() raises:
    var value=1
    var callback=Step(0)
    _=invoke_borrowed_repeated[String](value,callback)
