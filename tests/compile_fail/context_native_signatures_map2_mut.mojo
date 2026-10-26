# error: no matching method
from fp.functions import pipeline
def wrong(var left:Int,mut right:Int)->Int: return left+right
def main():
    var pointer:def(var Int,mut Int) thin ->Int=wrong
    _ = pipeline(Optional(1)).map2(Optional(2),pointer).get()
