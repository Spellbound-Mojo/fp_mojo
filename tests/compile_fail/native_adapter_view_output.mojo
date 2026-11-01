# error: no matching method
from fp.functions import pipeline, as_unary
from fp.data import ok

def double(var value: Int) -> Int: return value * 2
def label(var value: Int) -> String: return String(value)
def main():
    var success = as_unary(double)
    var failure = as_unary(label)
    _ = pipeline(ok[Int](1)).fold_owned(success, failure)
