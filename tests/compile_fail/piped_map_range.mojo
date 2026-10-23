# error: no matching method in call to 'map'
from fp.functions import piped

def square(value: Int) -> Int: return value * value

def main():
    _ = piped(range(3)).map(square).get()
