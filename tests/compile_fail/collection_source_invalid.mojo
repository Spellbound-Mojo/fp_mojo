# error: invalid call to 'fold_left': lacking evidence to prove correctness
from fp.iteration import fold_left

def add(total: Int, value: Int) -> Int:
    return total + value

def main():
    _ = fold_left(add, 0, 5)
