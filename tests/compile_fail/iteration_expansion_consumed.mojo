# error: use of uninitialized value 'values'
from fp.iteration import iterated
def main():
    var values: List[Int] = [1,2]
    _ = iterated(range(2)).zip(values^)
    print(len(values))
