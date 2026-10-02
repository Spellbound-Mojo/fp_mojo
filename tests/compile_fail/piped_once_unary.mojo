# error: no matching method in call to 'then'
# error: argument type 'PipedOnce' does not conform to trait 'Unary'
from fp.callables import OnceUnary
from fp.functions import piped

@fieldwise_init
struct PipedOnce(OnceUnary):
    var bias: Int
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var arg: Int) -> Int:
        return arg + self.bias

def main():
    _ = piped(3).then(PipedOnce(1)).get()
