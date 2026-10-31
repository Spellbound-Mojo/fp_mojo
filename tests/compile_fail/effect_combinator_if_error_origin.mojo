from fp.functions import pipeline
# Library branches keep their exact error origin; it cannot escape as another origin.
# error: cannot call function that may raise
# error: in context that supports an error type of 'Span[Int, origin_of(right)]'
from fp.data import Result, Ok
from fp.callables import OnceThunk

@fieldwise_init
struct EFBadBranchError[o: ImmOrigin](OnceThunk):
    var error: Span[Int, Self.o]
    comptime Out = Result[Int, String]
    comptime Error = Span[Int, Self.o]
    def call_once(deinit self) raises Self.Error -> Self.Out:
        raise self.error

def mismatch(left: List[Int], right: List[Int]) raises Span[Int, origin_of(right)]:
    _ = pipeline(Result[Bool, String](Ok(True))).if_effect(
        EFBadBranchError(Span(left)), EFBadBranchError(Span(left))).get()

def main():
    var left: List[Int] = [1]
    var right: List[Int] = [2]
    try: mismatch(left, right)
    except: pass
