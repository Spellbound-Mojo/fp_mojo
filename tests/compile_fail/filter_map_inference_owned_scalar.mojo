# error: no matching function
from fp.callables import Unary
from fp.iteration import filter_map
@fieldwise_init
struct Project(Unary):
    comptime Arg = Int
    comptime Out = Int
    def call(self, var value: Int) -> Int: return value
def main(): _ = filter_map(Project(), range(3))
