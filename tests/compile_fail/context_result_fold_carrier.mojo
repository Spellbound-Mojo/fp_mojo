# error: no matching method
from fp.functions import pipeline

def same(var value: Int) -> Int: return value
def main():
    _ = pipeline(Optional(1)).fold_owned(same, same)
