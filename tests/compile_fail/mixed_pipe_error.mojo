# error: pipe: stage 1 should take Int, return Int and raise Int or nothing
# error: raises String
from fp.functions import pipe, partial
def native(var value: Int) raises Int -> Int: raise value
def library(offset: Int, value: Int) raises String -> Int: raise String(offset + value)
def main():
    try: _ = pipe(3, native, partial(library, 2))
    except error: pass
