# error: no matching function
from fp.functions import flow
def native(var value: Int) -> Int: return value + 1
def main(): _ = flow(native, 3)
