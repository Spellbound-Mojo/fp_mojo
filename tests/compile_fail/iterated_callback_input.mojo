# error: no matching method in call to 'map'
from fp.iteration import iterated

def length(var value: String) -> Int:
    return value.byte_length()

def main():
    _ = iterated(range(3)).map(length)
