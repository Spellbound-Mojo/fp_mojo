# error: compose: stage 1 (argument 1) should take Int, return Int and raise Int or nothing
# error: raises String
from fp.functions import compose, Identity
def first(var value: Int) raises Int -> Int: raise value
def last(var value: Int) raises String -> Int: raise String(value)
def main(): _ = compose(Identity[Int](), last).compose(first)
