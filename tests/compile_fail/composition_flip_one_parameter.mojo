# error: no matching function in call to 'flip'
from fp.functions import flip


def inc(x: Int) -> Int:
    return x + 1


def main():
    _ = flip(inc)
