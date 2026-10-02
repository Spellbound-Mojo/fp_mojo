# error: flow: stage 1 should take Int, return Int and raise nothing
# error: it takes String, returns Int
from fp.functions import flow

def twice(value: Int) -> Int:
    return value * 2

def size(text: String) -> Int:
    return text.byte_length()

def main():
    var chain = flow(twice, size)
    _ = chain^
