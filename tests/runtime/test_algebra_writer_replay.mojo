"""Deferred Cartesian application replays only natively copyable captures."""
from fp.algebra import ListFamily, StringMonoid, map2
from fp.effects import ReaderT, WriterT, lift, writer, run, run_writer
from std.testing import assert_equal
from algebra_support import Add

comptime R=ReaderT[ListFamily,Int]
comptime W=WriterT[R,StringMonoid]


def assert_output(output:List[Tuple[String,Int]]) raises:
    assert_equal(len(output),4)
    var expected:List[Int]=[11,21,12,22]
    for index in range(4):
        assert_equal(output[index][0],"a" if index<2 else "b")
        assert_equal(output[index][1],expected[index])


def main() raises:
    var values:List[Tuple[String,Int]]=[Tuple(String("a"),1),Tuple(String("b"),2)]
    var numbers:List[Int]=[10,20]
    var left=writer[W,Int](lift[R](values^))
    var right=lift[W](lift[R](numbers^))
    var computation=map2[W](Add(),left^,right^)
    var copy=computation.copy()
    var environment=0
    assert_output(run[R](run_writer[W](computation^),environment))
    assert_output(run[R](run_writer[W](copy^),environment))
    print("Writer/Reader/List: copied deferred application, Cartesian value and log order")
