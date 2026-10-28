from fp.callables import BinaryContract, RepeatableBinary
from fp.iteration import fold_left, fold_until, reduce_optional, iterated
from fp.data import ControlFlow, Break
from std.iter import Iterator
from std.testing import assert_equal
from test_repeatable_folds import Add, Until, Failure

def folded[A:Movable & Deinitable,I:Iterator,F:BinaryContract & Movable & Deinitable](var step:F,var initial:A,var source:I
) raises F.Error -> A where F.First==A and F.Second==I.Element and F.Out==A and RepeatableBinary[F]:
    return fold_left(step^,initial^,source^)

def reduced[I:Iterator,F:BinaryContract & Movable & Deinitable](var step:F,var source:I
) raises F.Error -> Optional[F.Out] where F.First==F.Out and F.Second==F.Out and I.Element==F.Out and RepeatableBinary[F]:
    return iterated(source^).reduce_optional(step^)

def stopped[A:Movable & Deinitable,B:Movable & Deinitable,I:Iterator,F:BinaryContract & Movable & Deinitable](var step:F,var initial:A,var source:I
) raises F.Error -> ControlFlow[B,A] where F.First==A and F.Second==I.Element and F.Out==ControlFlow[B,A] and RepeatableBinary[F]:
    return fold_until[B=B](step^,initial^,source^)

def main() raises:
    assert_equal(folded(Add(0),0,range(1,3)),6)
    var value=reduced(Add(0),range(1,3))
    assert_equal(value.take(),4)
    var stop=stopped(Until(0),0,range(1,4))
    assert_equal(stop^.unwrap[Break[String]]().into_payload(),"3")
    try:_=folded(Failure(0),0,range(1,2))
    except error:
        comptime assert type_of(error)==Int
        assert_equal(error,2)
    try: _=reduced(Failure(0),range(1,3))
    except error:
        comptime assert type_of(error)==Int
        assert_equal(error,4)
