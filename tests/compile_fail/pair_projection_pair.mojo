# error: cannot be converted
from fp.functions import first
def increment(value: Int) -> Int: return value + 1
def main(): _ = first[String](increment)((1, String("id"), 2))
