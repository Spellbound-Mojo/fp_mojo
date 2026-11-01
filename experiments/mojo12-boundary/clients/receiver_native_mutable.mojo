from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct Fault(Movable):
    var code: Int
@fieldwise_init
struct Counter(Movable):
    var count: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

def invoke[F: def(var String) raises Fault -> Int](mut function: F, var text: String) raises Fault -> Int:
    return function(text^)
def exercise(drops: ArcPointer[Int]) raises:
    var counter = Counter(0, drops)
    def callback(var text: String) raises Fault {var counter^} -> Int:
        counter.count += 1
        if text.byte_length() == 0: raise Fault(counter.count)
        return counter.count
    for n in range(1, 4):
        var actual: Int
        try: actual = invoke(callback, String("a"))
        except error: actual = -error.code
        assert_equal(actual, n)
    assert_equal(drops[], 0)
    _ = callback^
def main() raises:
    var drops = ArcPointer(0)
    exercise(drops)
    assert_equal(drops[], 1)
