# error: use of uninitialized value 'chain'
from fp.functions import pipeline

def twice(value: Int) -> Int:
    return value * 2

def main():
    var chain = pipeline(3).then(twice)
    _ = chain^.get()
    _ = chain^.get()
