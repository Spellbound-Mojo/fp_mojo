# error: invalid call to 'ap': violated constraint
from fp.functions import pipeline
from fp.callables import OnceUnary
@fieldwise_init
struct APOnce(OnceUnary):
    var offset: Int
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var arg: Int) -> Int: return arg+self.offset
def main():
    var functions = List[APOnce]()
    functions.append(APOnce(1))
    var values: List[Int] = [2]
    _ = pipeline(functions^).ap(values^)
