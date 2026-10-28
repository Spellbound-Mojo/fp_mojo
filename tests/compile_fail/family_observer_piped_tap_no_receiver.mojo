# error: no matching method in call to 'tap'
from fp.callables import BorrowOnceCallable,BorrowMutableCallable,BorrowCallContract
from fp.functions import piped,pipeline
struct NoCall(BorrowCallContract):
    comptime Payload=Int
    comptime Result=Int
    def __init__(out self):pass
def main() raises:_=piped(7).tap(NoCall())
