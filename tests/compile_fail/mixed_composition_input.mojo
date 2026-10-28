# error: flow: stage 1 should take Int
# error: it takes String
from fp.functions import flow, Identity
def size(var value: String) -> Int: return value.byte_length()
def main(): _ = flow(Identity[Int](), size)
