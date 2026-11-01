# error: no matching method
from fp.functions import pipeline
def bad(var value: Int) -> Int: return value
def main(): _ = pipeline(range(3)).find_map(bad).get()
