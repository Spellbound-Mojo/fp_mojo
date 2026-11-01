# error: constraint
from fp.effects import Ref
from fp.callables import BorrowCallable
@fieldwise_init
struct Wrong(BorrowCallable):
    comptime Payload=Int
    comptime Result=Int
    comptime Failure=String
    def invoke(self,ref value:Int) raises String -> Int:raise String("wrong")
def main():
    _=Ref(1).inspect[Error](Wrong())
