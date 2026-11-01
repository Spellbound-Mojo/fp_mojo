# error: use of uninitialized value
from fp.functions import pipeline
from fp.callables import OnceThunk
@fieldwise_init
struct Factory(OnceThunk):
    var value: Int
    comptime Out = Int
    def call_once(deinit self) -> Int: return self.value

def main():
    var factory = Factory(7)
    _ = pipeline(Optional(1)).get_or_else(factory^)
    _ = factory^.call_once()
