# error: no matching function in call to 'merge'
from fp.functions import merge
def increment(var value: Int) -> Int: return value+1
def decorate(var value: String) -> String: return value+"!"
def main(): _ = merge(increment, decorate)
