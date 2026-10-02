# error: use of uninitialized value 'chain'
from fp.functions import piped

def twice(value: Int) -> Int:
    return value * 2

def main():
    var chain = piped(3).then(twice)
    _ = chain^.get()
    _ = chain^.get()
