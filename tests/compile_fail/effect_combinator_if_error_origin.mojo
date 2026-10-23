from fp.functions import piped
# error: constraint
from fp.data import Result, Ok
from fp.callables import OnceThunk

@fieldwise_init
struct EFBadBranchError[o: ImmOrigin](OnceThunk):
    var error: Span[Int, Self.o]
    comptime Out = Result[Int, String]
    comptime Error = Span[Int, Self.o]
    def call_once(deinit self) raises Self.Error -> Self.Out:
        raise self.error

def mismatch(left: List[Int], right: List[Int]):
    try:
        _ = piped(Result[Bool, String](Ok(True))).if_effect[X=Span[Int, origin_of(right)]](
            EFBadBranchError(Span(left)), EFBadBranchError(Span(left))).get()
    except: pass

def main(): mismatch([1], [2])
