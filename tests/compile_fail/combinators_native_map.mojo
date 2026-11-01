# error: no matching method in call to 'then'
from fp.functions import pipeline
from fp.iteration import map

def square(value: Int) -> Int: return value * value

def main():
    _ = pipeline(range(3)).then(map, square).get()
