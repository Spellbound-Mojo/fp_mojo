# error: no matching method
from fp.data import ok
from fp.functions import pipeline

def success(var value: Int) -> Int: return value
def failure(var error: String) -> String: return error^
def main():
    _ = pipeline(ok[String](1)).fold_owned(success, failure)
