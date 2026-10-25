# error: no matching method
# The callbacks fit Result[Int, String]; only the source carrier is unsupported.
from fp.functions import pipeline
from fp.data import Result, Ok

def first(value:Int) -> Bool: return True
def second(value:Int) -> String: return String("failure")

def main():
    _ = pipeline(List[Int]([1])).ensure(first, second).get()
