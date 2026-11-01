# error: no matching method
# The callbacks fit Result[Int, String]; only the source carrier is unsupported.
from fp.functions import pipeline
from fp.data import Result, Ok

def first(var value:Int) -> Int: return 1
def second(var value:String) -> Int: return 1

def main():
    _ = pipeline(List[Int]([1])).redeem(first, second).get()
