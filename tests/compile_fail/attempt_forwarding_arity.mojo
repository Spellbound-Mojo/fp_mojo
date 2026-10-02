# error: no matching function in call to 'attempt'
from fp.data import attempt

def three(first: Int, second: Int, third: Int) -> Int: return first + second + third

def main(): _ = attempt(three, 1, 2, 3)
