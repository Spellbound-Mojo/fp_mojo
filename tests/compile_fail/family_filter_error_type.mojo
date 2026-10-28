# error: cannot call function that may raise
from fp.callables import BorrowMutableCallable
from fp.functions import pipeline
struct Fails(BorrowMutableCallable):
    comptime Payload = Int
    comptime Result = Bool
    comptime Failure = Int
    def __init__(out self): pass
    def invoke_mut(mut self, ref value: Int) raises Int -> Bool: raise value

def wrong(var values: List[Int]) raises String -> List[Int]:
    return pipeline(values^).filter(Fails()).get()
def main(): pass
