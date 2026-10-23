# error: no matching method in call to 'partition_map'
from fp.iteration import iterated, Unbounded
def i3_wrong(var value: Int) -> Optional[Int]: return value
def main(): _ = iterated(range(3)).partition_map(i3_wrong, buffer=Unbounded())
