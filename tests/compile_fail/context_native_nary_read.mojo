# error: function type conversions
from fp.functions import pipeline
def wrong(a: Int, var b: String, var c: Int) -> Int: return a+c
def main():
    var pointer: def(Int, var String, var Int) thin -> Int = wrong
    _ = pipeline(Optional(1)).map_n((Optional(String("x")), Optional(2)), pointer).get()
