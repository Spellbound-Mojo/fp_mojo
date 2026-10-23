# error: no matching method in call to 'then'
from fp.functions import piped
from fp.combinators import map

def square(value: Int) -> Int: return value * value

def main():
    _ = piped(range(3)).then(map, square).get()
