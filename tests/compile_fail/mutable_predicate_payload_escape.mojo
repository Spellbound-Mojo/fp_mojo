# error: cannot implicitly convert
from fp.callables import BorrowMutableCallable
struct Escape(BorrowMutableCallable):
    comptime Payload=Int
    comptime Result=Pointer[Int,ImmStaticOrigin]
    def __init__(out self):pass
    def invoke_mut(mut self,ref value:Int)->Self.Result:return Pointer(to=value)
def main():pass
