# error: no matching method
from fp.functions import pipeline

def same(value: Int) -> Int: return value
def main():
    _ = pipeline(Optional(1)).fold(same, same)
