# error: invalid call
from fp.functions import pipeline
from owned_fill_support import Box

def main():
    _ = pipeline(List[Int]([1, 2])).tuple_right(Box(1))
