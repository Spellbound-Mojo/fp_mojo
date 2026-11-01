# error: no matching method
from fp.data import ok
from fp.functions import pipeline

def wrong(var value: String) -> Int: return value.byte_length()
def fallback(error: String) -> Int: return 0
def main():
    _ = pipeline(ok[String](String("value"))).fold(wrong, fallback)
