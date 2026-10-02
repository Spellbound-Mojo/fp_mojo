# error: no matching function in call to 'as_unary'
from fp.functions import pipe, as_unary
def split(a: Int, b: String) -> Int: return a + b.byte_length()
def main():
    var a = as_unary(split)
    _ = pipe((1, String("x")), a)
