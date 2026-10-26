# error: Dict callbacks must be repeatable
from fp.functions import pipeline_values
from fp.callables import OnceUnary

@fieldwise_init
struct Once(OnceUnary):
    comptime Arg = Int
    comptime Out = String
    def call_once(deinit self, var value: Int) -> String: return String(value)

def main():
    var values = Dict[String, Int]()
    _ = pipeline_values(values^).map(Once())
