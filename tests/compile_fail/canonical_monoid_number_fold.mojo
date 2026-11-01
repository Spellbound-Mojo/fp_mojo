# error: no matching function in call to 'fold_map'
from fp.iteration import fold_map
def twice(var value: Int) -> Int: return value * 2
def main() raises:
    _ = fold_map(range(2), twice)
