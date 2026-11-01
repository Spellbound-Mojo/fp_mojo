"""Generic clients need only their existing repeatable shape constraint."""
from fp.callables import mut_ref,UnaryContract,BinaryContract,ThunkContract,BorrowCallContract,RepeatableUnary,RepeatableBinary,RepeatableThunk,RepeatableBorrow,call_once,invoke_borrowed_once
from fp.functions import pipeline
from fp.iteration import iterated
from test_mutable_ref import Unary,Binary,Thunk,Predicate
from std.testing import assert_equal

def mapped[F:UnaryContract & Movable & Deinitable](mut callback:F,var values:List[F.Arg]) raises F.Error -> List[F.Out] where RepeatableUnary[F]:
    return pipeline(values^).map(mut_ref(callback)).get()
def folded[F:BinaryContract & Movable & Deinitable](mut callback:F,var initial:F.First,var values:List[F.Second]) raises F.Error -> F.First where RepeatableBinary[F] and F.Out==F.First:
    return iterated(values^).fold_left(mut_ref(callback),initial^)
def produced[F:ThunkContract & Movable & Deinitable](mut callback:F) raises F.Error -> F.Out where RepeatableThunk[F]:
    return call_once(mut_ref(callback))
def observed[F:BorrowCallContract & Movable & Deinitable](mut callback:F,ref value:F.Payload) raises F.Failure -> F.Result where RepeatableBorrow[F]:
    return invoke_borrowed_once[F.Failure](value,mut_ref(callback))
def main() raises:
    var unary=Unary(0)
    assert_equal(mapped(unary,[1,2]),[2,4])
    assert_equal(unary.calls,2)
    var binary=Binary(0)
    assert_equal(folded(binary,0,[0,1,2]),9)
    assert_equal(binary.calls,3)
    var thunk=Thunk(0)
    assert_equal(produced(thunk),1)
    assert_equal(thunk.calls,1)
    var predicate=Predicate(0)
    var value=3
    assert_equal(observed(predicate,value),False)
    assert_equal(observed(predicate,value),True)
    assert_equal(predicate.calls,2)
