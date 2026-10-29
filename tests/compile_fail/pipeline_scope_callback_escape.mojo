# error: origin
from fp.functions import pipeline
from fp.effects import Reader, ask
from fp.callables import BorrowCallable
@fieldwise_init
struct Shift[o: ImmOrigin](BorrowCallable):
    var amount: Pointer[Int,Self.o]
    comptime Payload = Int
    comptime Result = Int
    def invoke(self, ref value: Int) -> Int: return value + self.amount[]
comptime R = Reader[Int]
def escape() -> R.Localized[R.Asked,Shift[ImmUntrackedOrigin]]:
    var amount = 2
    return pipeline(ask[R]()).local(Shift(Pointer(to=amount))).get()
def main(): _ = escape()
