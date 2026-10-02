# error: no matching function in call to 'attempt'
from fp.data import attempt

def scaled(value: Int, *, scale: Int) -> Int: return value * scale

def main(): _ = attempt(scaled, 3, scale=2)
