# error: use of uninitialized value 'values'
from fp.iteration import collect_list
from std.iter import iter

def main():
    var values: List[Int] = [1, 2]
    _ = collect_list(iter(values^))
    print(len(values))
