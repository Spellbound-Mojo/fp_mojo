# error: value of type 'List[Int]' cannot be implicitly copied
from fp.iteration import fold_left

def add(total: Int, value: Int) -> Int:
    return total + value

def main():
    var values: List[Int] = [1, 2]
    _ = fold_left(add, 0, values)
    print(len(values))
