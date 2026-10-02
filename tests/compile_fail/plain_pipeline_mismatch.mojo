# error: pipe: stage 1 should take Int, return Int and raise nothing
# error: it takes String, returns Int
from fp.functions import pipe

def twice(value: Int) -> Int:
    return value * 2

def size(text: String) -> Int:
    return text.byte_length()

def main() raises:
    _ = pipe(3, twice, size)
