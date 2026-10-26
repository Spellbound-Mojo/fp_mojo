# error: no matching method
from fp.functions import pipeline
def wrong(var total:Int,var value:Int)->String: return String(total+value)
def main():
    var pointer:def(var Int,var Int) thin ->String=wrong
    _ = pipeline(List[Int]([1])).fold_left(pointer,0).get()
