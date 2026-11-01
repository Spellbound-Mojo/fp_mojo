from fp.functions import pipeline
# error: constraint
from fp.effects import ReaderAction
from fp.effects.io import IO, IOContext
from fp.effects.outcomes import Outcome
@fieldwise_init
struct EscapeContext(ReaderAction):
    comptime Family = IO[Error]
    comptime Env = IOContext[Error]
    comptime Value = Span[IOContext[Error], ImmUntrackedOrigin]
    comptime Out[o: ImmOrigin] = Outcome[Span[IOContext[Error], o], Error]
    def run[o: ImmOrigin](deinit self, ref[o] env: Self.Env) -> Self.Out[o]: return None
def main():
    _ = pipeline(EscapeContext()).run_io()
