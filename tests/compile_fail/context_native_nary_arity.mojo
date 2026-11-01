# error: no matching method
from fp.functions import pipeline
def wrong(var a: Int, var b: String) -> Int: return a
def main():
    var pointer: def(var Int, var String) thin -> Int = wrong
    _ = pipeline(Optional(1)).map_n((Optional(String("x")), Optional(2)), pointer).get()
