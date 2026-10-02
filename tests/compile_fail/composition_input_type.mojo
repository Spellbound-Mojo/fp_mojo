# error: flow: stage 1 should take Int
# error: it takes String
from fp.functions import flow, Identity, as_unary


def f(var x: String) -> Int:
    return x.byte_length()


def main():
    _ = flow(Identity[Int](), as_unary(f))
