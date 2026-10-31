# error: use of uninitialized value 'predicate'
from fp.functions import pipeline
from fp.callables import BorrowCallable
from std.memory import ArcPointer
@fieldwise_init
struct Predicate(BorrowCallable):
    comptime Payload = Int
    comptime Result = Bool
    var calls: ArcPointer[Int]
    def invoke(self, ref payload: Int) capturing -> Bool:
        self.calls[] += 1
        return payload > 0

def main():
    var predicate = Predicate(ArcPointer(0))
    var xs: List[Int] = [1, 2]
    _ = pipeline(xs^).filter_not(predicate^).get()
    var y = 1
    _ = predicate.invoke(y)
