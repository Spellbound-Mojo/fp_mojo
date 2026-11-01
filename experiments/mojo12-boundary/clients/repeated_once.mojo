# error: List callbacks must be repeatable
from fp._architecture import piped
from fp.callables import OnceUnary

@fieldwise_init
struct MapOnce(OnceUnary):
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var arg: Int) -> Int: return arg

def main():
    var values: List[Int] = [1, 2]
    _ = piped(values^).map(MapOnce()).get()
