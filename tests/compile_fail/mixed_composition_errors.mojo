# error: compose: stage 1 (argument 0) should take Int, return Int and raise Int or nothing
# error: raises String
from fp.functions import compose, partial
def native(var value: Int) raises Int -> Int: raise value
def library(offset: Int, value: Int) raises String -> Int: raise String(offset + value)
def main(): _ = compose(partial(library, 2), native)
