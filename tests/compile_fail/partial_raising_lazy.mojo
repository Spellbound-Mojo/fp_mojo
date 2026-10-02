# error: no matching function in call to 'map'
# error: violated constraint
# Lazy iteration adapters cannot raise, so a raising partial is rejected.
from std.iter import iter
from fp.functions import partial
from fp.iteration import map
def checked(limit: Int, x: Int) raises String -> Int:
    if x > limit:
        raise String("too big")
    return x
def main():
    var xs: List[Int] = [1, 2]
    _ = map(partial(checked, 1), iter(xs))
