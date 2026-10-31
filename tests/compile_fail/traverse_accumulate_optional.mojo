# error: no matching function in call to 'traverse'
from fp.iteration import traverse
from fp.algebra import Accumulate
def check(var value: Int) -> Optional[Int]: return value
def main() raises:
    _ = traverse[Accumulate](List[Int]([1]), check)
