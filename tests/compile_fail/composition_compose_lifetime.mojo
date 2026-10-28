# error: use of uninitialized value 'chain'
from fp.functions import flow, Identity
from fp.iteration import iterated
def plus(var value: Int) -> Int: return value + 1
def main():
    var chain = flow(Identity[Int](), Identity[Int]())
    var pending = iterated(range(2)).map(chain)
    var extended = chain^.compose(plus)
    _ = extended(1)
    _ = pending^.collect_list()
