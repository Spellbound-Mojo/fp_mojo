# error: no matching method
# error: constraint
from fp.functions import kleisli, flow
from fp.iteration import iterated
from fp.algebra import OptionalFamily, ResultFamily
def identity(var value: Int) -> Int: return value
def main():
    var chain = flow(identity, identity)
    _ = iterated(range(2)).traverse_void(chain)
