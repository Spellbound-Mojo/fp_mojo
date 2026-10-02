# error: .origin of the first value
from fp.callables import BorrowOnceCallable
from fp.data import Result, Ok

@fieldwise_init
struct Escape[origin: ImmOrigin](BorrowOnceCallable):
    comptime Payload = String
    comptime Result = Pointer[String,Self.origin]
    def invoke_once(deinit self, ref payload: String) raises Never capturing -> Self.Result:
        return Pointer[String,ImmOrigin(origin_of(payload))](to=payload)

def main():
    var owner = String('external')
    var subject = Result[String,String](Ok(String('scoped')))
    _ = subject.fold_once(Escape[origin_of(owner)](),Escape[origin_of(owner)]())
