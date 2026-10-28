# error: pipe: stage 0 should take Int
# error: it takes String
from fp.functions import pipe, Identity
def size(var value: String) -> Int: return value.byte_length()
def main(): _ = pipe(3, size, Identity[Int]())
