from fp.iteration import map_accumulate, iterated
from fp.callables import MutableBinary, BinarySignature
from fp.functions import as_binary
from std.testing import assert_equal

def labeled(var index: Int, var value: Int) -> Tuple[Int,String]:
    return (index + 1, String(index) + ":" + String(value))
@fieldwise_init
struct Running(MutableBinary):
    var calls: Int
    comptime First = Int
    comptime Second = Int
    comptime Out = Tuple[Int,Int]
    def call_mut(mut self, var state: Int, var value: Int) -> Self.Out:
        self.calls += 1
        return (state + value, self.calls)

comptime Named = def(var Int, var Int) thin -> Tuple[Int,String]

def main() raises:
    var chained = iterated([5,6]).map_accumulate(labeled, 0)
    assert_equal(chained[0], 2)
    assert_equal(chained[1], ["0:5", "1:6"])
    var direct = map_accumulate(labeled, 0, [5])
    assert_equal(direct[0], 1)
    assert_equal(direct[1], ["0:5"])
    var pointer: Named = labeled
    var labeled_values = map_accumulate[Y=String](pointer, 3, [10,20])
    assert_equal(labeled_values[0], 5)
    assert_equal(labeled_values[1], ["3:10", "4:20"])
    var counted = map_accumulate(Running(0), 0, range(4))
    assert_equal(counted[0], 6)
    assert_equal(counted[1], [1,2,3,4])
    var prefix = String("row ")
    def captured(var index: Int, var value: Int) {var prefix^} -> Tuple[Int,String]:
        return (index + 1, prefix + String(value))
    var selected = BinarySignature[Int,Int,Tuple[Int,String]].capture(captured^)
    var mapped = map_accumulate(selected, 0, range(2))
    assert_equal(mapped[0], 2)
    assert_equal(mapped[1], ["row 0", "row 1"])
    var shared = iterated([4]).map_accumulate(selected, 0)
    assert_equal(shared[1], ["row 4"])
    var again = map_accumulate(selected^, 5, [8])
    assert_equal(again[0], 6)
    assert_equal(again[1], ["row 8"])
    var literal: def(var Int, var Int) thin -> Tuple[Int,String] = labeled
    var explicit = map_accumulate[Y=String](literal, 0, [8])
    assert_equal(explicit[0], 1)
    assert_equal(explicit[1], ["0:8"])
