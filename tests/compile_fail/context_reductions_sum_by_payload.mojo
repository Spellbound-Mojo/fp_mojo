# error: no matching method
from fp.functions import pipeline
def bad(var value: Int) -> String: return String(value)
def main(): _ = pipeline(range(3)).sum_by(bad).get()
