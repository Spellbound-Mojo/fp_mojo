# error: no matching method in call to 'map'
from fp.functions import pipeline

def square(value: Int) -> Int: return value * value

def main():
    _ = pipeline(range(3)).map(square).get()
