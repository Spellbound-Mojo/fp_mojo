# error: use of uninitialized value
from fp.functions import pipeline
from fp.effects import Reader, ask
def change(value: Int) -> Int: return value + 1
def main():
    var source = pipeline(ask[Reader[Int]]())
    _ = source^.local(change)
    _ = source^.get()
