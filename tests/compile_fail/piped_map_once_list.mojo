# error: no matching method in call to 'map'
from fp.functions import pipeline
from fp.callables import OnceUnary

@fieldwise_init
struct MapOnce(OnceUnary):
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var arg: Int) -> Int: return arg

def main():
    var values: List[Int] = [1, 2]
    _ = pipeline(values^).map(MapOnce()).get()
