# error: use of uninitialized value 'callback'
from fp.functions import first
def increment(value: Int) -> Int: return value + 1
def main():
    var callback = first[String](increment)
    _ = callback^.call_once((1, String("id")))
    _ = callback((2, String("id")))
