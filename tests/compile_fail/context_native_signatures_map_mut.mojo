# error: no matching method
from fp.functions import pipeline
def wrong(mut value:Int)->Int: return value
def main():
    var pointer:def(mut Int) thin ->Int=wrong
    _ = pipeline(Optional(1)).map(pointer).get()
