# error: use of uninitialized value
from fp.functions import pipeline
from owned_fill_support import Box

def main():
    var attached = Box(7)
    _ = pipeline(Optional(1)).tuple_left(attached^).get()
    print(attached.value)
