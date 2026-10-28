# error: no matching method
from fp.data import ok
from fp.functions import pipeline

def success(value: Int) -> Int: return value
def failure(error: String) -> String: return error^
def main():
    _ = pipeline(ok[String](1)).fold(success, failure)
