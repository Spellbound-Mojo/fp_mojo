# error: no matching method
from fp.functions import pipeline
def wrong(value:Int)->Int: return value
def main():
    var pointer:def(Int) thin ->Int=wrong
    _ = pipeline(Optional(1)).filter(pointer).get()
