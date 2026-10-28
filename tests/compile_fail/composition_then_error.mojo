# error: compose: stage 2 (argument 0) should take Int, return Int and raise Int or nothing
# error: raises String
from fp.functions import compose, Identity
def first(var value: Int) raises Int -> Int: raise value
def last(var value: Int) raises String -> Int: raise String(value)
def main(): _ = compose(Identity[Int](), first).then(last)
