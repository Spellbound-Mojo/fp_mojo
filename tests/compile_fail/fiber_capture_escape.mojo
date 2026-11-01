# error: cannot implicitly convert
from fp.effects import unsafe_start
from fp.effects import delay, Outcome
from fp.callables import OnceThunk
@fieldwise_init
struct Borrowed[o:ImmOrigin](OnceThunk):
    var owner:Pointer[List[Int],Self.o]
    comptime Out=Span[Int,Self.o]
    def call_once(deinit self)->Self.Out:return Span(self.owner[])
def escape() raises -> Outcome[Span[Int,ImmUntrackedOrigin],Error]:
    var owner=List[Int]([1])
    var child=unsafe_start(delay[Error](Borrowed(Pointer(to=owner))))
    return child^.join()
def main() raises:
    _=escape()
