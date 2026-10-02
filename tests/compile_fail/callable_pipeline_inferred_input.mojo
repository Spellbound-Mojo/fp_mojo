# error: pipe: stage 1 should take String
# error: it takes Int
from fp.functions import pipe, as_unary
def text(var value: Int) -> String: return String(value)
def length(var value: Int) -> Int: return value
def main():
    var a = as_unary(text)
    var b = as_unary(length)
    _ = pipe(1, a, b)
