# error: constraint
from fp.effects.io import delay
from fp.callables import OnceThunk
@fieldwise_init
struct WrongError(OnceThunk):
    comptime Out = Int
    comptime Error = String
    def call_once(deinit self) raises String -> Int: raise String("error")
def main():
    _ = delay[Error](WrongError())
