# error: use of uninitialized value
from fp.functions import pipeline
from owned_fill_support import Box

def main():
    var source = Optional(Box(7))
    _ = pipeline(source^).tuple_right(1).get()
    print(Bool(source))
