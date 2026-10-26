# error: no matching method
from fp.functions import pipeline
def wrong(var total:Int,var value:Int)->Optional[Int]: return Optional(total+value)
def main():
    var pointer:def(var Int,var Int) thin ->Optional[Int]=wrong
    _ = pipeline(List[Int]([1])).fold_until(pointer,0).get()
