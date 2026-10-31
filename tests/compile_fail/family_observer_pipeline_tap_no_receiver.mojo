# error: no matching method in call to 'tap'
from fp.callables import BorrowOnceCallable,BorrowMutableCallable,BorrowCallContract
from fp.functions import pipeline
struct NoCall(BorrowCallContract):
    comptime Payload=Int
    comptime Result=Int
    def __init__(out self):pass
def main() raises:_=pipeline(7).tap(NoCall())
