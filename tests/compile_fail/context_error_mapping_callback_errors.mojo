# error: no matching method in call to 'map_both'
from fp.functions import pipeline
from fp.callables import Unary
from fp.data import Result, Ok
@fieldwise_init
struct First(Unary):
    comptime Arg = Int
    comptime Out = String
    comptime Error = Int
    def call(self, var value: Int) raises Int -> String: return String(value)
@fieldwise_init
struct Second(Unary):
    comptime Arg = String
    comptime Out = Int
    comptime Error = String
    def call(self, var value: String) raises String -> Int: return value.byte_length()
def main():
    _ = pipeline(Result[Int,String](Ok(1))).map_both(First(),Second())
