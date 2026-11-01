# error: constraint
from fp.functions import kleisli
from fp.iteration import iterated
from fp.algebra import OptionalFamily
def source(x: Int) raises Int -> Optional[Int]: return Optional(x)
def main():
    var chain = kleisli[OptionalFamily](source)
    _ = iterated(range(3)).map(chain)
