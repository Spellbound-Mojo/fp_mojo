# error: cannot call function that may raise 'IteratedActualFault' in context that supports an error type of 'IteratedExpectedFault'
from fp.iteration import iterated

@fieldwise_init
struct IteratedExpectedFault(Movable, Writable):
    var code: Int

@fieldwise_init
struct IteratedActualFault(Movable, Writable):
    var code: Int

def fail(var total: Int, var value: Int) raises IteratedActualFault -> Int:
    raise IteratedActualFault(value)

def invalid() raises IteratedExpectedFault -> Int:
    return iterated(range(3)).fold_left(fail, 0)

def main() raises:
    _ = invalid()
