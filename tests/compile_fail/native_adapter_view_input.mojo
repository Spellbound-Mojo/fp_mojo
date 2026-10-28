# error: no matching method
from fp.functions import pipeline, as_unary

def size(var value: String) -> Int: return value.byte_length()
def main():
    var callback = as_unary(size)
    _ = pipeline(Optional(1)).map(callback).get()
