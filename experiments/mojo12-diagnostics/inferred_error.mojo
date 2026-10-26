# Invalid convention: the callback consumes a value, but accept borrows it.
# Mojo 1.2.0 (2016d0cd) crashes while inferring E. No FP import is involved.
def accept[A: Movable & Deinitable, R: Movable & Deinitable,
           E: Movable & Deinitable, //, F: def(A) raises E -> R](function: F):
    pass

def callback(var value: Int) -> Bool:
    return value > 0

def main():
    accept(callback)
