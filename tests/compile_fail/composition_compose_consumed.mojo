# error: use of uninitialized value 'chain'
from fp.functions import flow, Identity
def plus(var value: Int) -> Int: return value + 1
def main():
    var chain = flow(Identity[Int](), Identity[Int]())
    var extended = chain^.compose(plus)
    _ = chain(1)
    _ = extended(1)
