from context_product_contract_support import forward
from fp.algebra import Monoid
from fp.algebra.contracts import ProductContract
from fp.effects import Writer, WriterT, Reader, writer, run_writer, run
from std.testing import assert_equal

@fieldwise_init
struct FailingLog(Monoid):
    comptime Value = Int
    comptime Error = Int
    @staticmethod
    def empty() raises Int -> Int:
        return 0
    @staticmethod
    def combine(var left: Int, var right: Int) raises Int -> Int:
        raise 77

def main() raises:
    comptime I = Writer[FailingLog]
    var code = 0
    try:
        var left = writer[I,Int]((0,1))
        var right = writer[I,Int]((0,2))
        comptime assert ProductContract[I,type_of(left),type_of(right)].Error == Int
        _ = forward[I](left^,right^)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,77)
    comptime G = Reader[Int]
    comptime D = WriterT[G,FailingLog]
    var constructed: Bool
    code = 0
    try:
        var left = writer[D,Int](G.pure((0,1)))
        var right = writer[D,Int](G.pure((0,2)))
        comptime assert ProductContract[D,type_of(left),type_of(right)].Error == Never
        var pending = forward[D](left^,right^)
        constructed = True
        _ = run[G](run_writer[D](pending^),0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(constructed,True)
    assert_equal(code,77)
