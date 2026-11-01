# error: no matching method
from fp.data import ok
from fp.functions import pipeline

def wrong(mut value: Int) -> Int: return value
def fallback(var error: String) -> Int: return 0
def main():
    _ = pipeline(ok[String](1)).fold_owned(wrong, fallback)
