"""Optional and Writer adapt activity and carry through the same traversal loop."""
from fp.algebra import traverse, ListFamily, StringMonoid
from fp.effects import Reader, OptionalT, Writer, writer, run_writer, action, run
from fp.callables import BorrowOnceCallable, as_unary
from std.testing import assert_equal
from algebra_support.iterators import Counted
from algebra_support import ints

comptime R=Reader[Int]
comptime W=Writer[StringMonoid]

@fieldwise_init
struct ReadOptional(BorrowOnceCallable):
    var item:Int
    comptime Payload=Int
    comptime Result=Optional[Int]
    def invoke_once(deinit self,ref environment:Int) raises Never capturing ->Optional[Int]:
        if self.item==3:
            return Optional[Int]()
        return Optional(self.item+environment)

def option(var item:Int)->type_of(action[R,Optional[Int]](ReadOptional(0))):
    return action[R,Optional[Int]](ReadOptional(item))

def logged(var item:Int)->type_of(writer[W,Int](Tuple(String(),0))):
    return writer[W,Int](Tuple(String(item),item*2))

def main() raises:
    for count in [0,2,5]:
        var pulls=0
        var computation=traverse[ListFamily,OptionalT[R]](as_unary(option),Counted(Pointer(to=pulls),0,count))
        assert_equal(pulls,0)
        var environment=10
        var output=run[R](computation^,environment)
        assert_equal(Bool(output),count!=5)
        assert_equal(pulls,3 if count==5 else count+1)
        if output:
            assert_equal(output.take(),List[Int]() if count==0 else ints(11,12))
    for count in [0,3]:
        var pulls=0
        var output=run_writer[W](traverse[ListFamily,W](as_unary(logged),Counted(Pointer(to=pulls),0,count)))
        assert_equal(output[0],"" if count==0 else "123")
        assert_equal(output[1],List[Int]() if count==0 else ints(2,4,6))
        assert_equal(pulls,count+1)
    print("layer traversal: OptionalT Reader short circuit and Writer log order")
