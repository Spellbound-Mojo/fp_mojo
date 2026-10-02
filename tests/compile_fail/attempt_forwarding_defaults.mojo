# error: no matching function in call to 'attempt'
from fp.data import attempt

def defaults(first: Int, second: Int = 3) -> Int: return first * 10 + second

def main(): _ = attempt(defaults, 2)
