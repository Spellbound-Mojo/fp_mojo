# error: no matching method in call to 'ap'
from fp.functions import piped
from fp.callables import Unary
@fieldwise_init
struct APResource(Movable):
    var value: Int
@fieldwise_init
struct APFunction(Unary, ImplicitlyCopyable):
    comptime Arg = APResource
    comptime Out = Int
    def call(self, var arg: APResource) -> Int: return arg.value
def main():
    var functions = List[APFunction]()
    functions.append(APFunction())
    var values = List[APResource]()
    values.append(APResource(2))
    _ = piped(functions^).ap(values^)
