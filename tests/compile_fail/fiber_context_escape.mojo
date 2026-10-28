# error: constraint
from fp.effects import unsafe_start
from fp.effects import ReaderAction, IO, IOContext, Outcome
@fieldwise_init
struct Escape(ReaderAction):
    comptime Family=IO[Error]
    comptime Env=IOContext[Error]
    comptime Value=Span[IOContext[Error],ImmUntrackedOrigin]
    comptime Out[o:ImmOrigin]=Outcome[Span[IOContext[Error],o],Error]
    def run[o:ImmOrigin](deinit self,ref[o] env:Self.Env)->Self.Out[o]:return None
def main() raises:
    _=unsafe_start(Escape())
