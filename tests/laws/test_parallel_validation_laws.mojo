"""Accumulating Result composition respects associativity and pure identity."""
from fp.data import Result,Ok,Err
from std.testing import assert_equal

comptime PVLawResult=Result[Int,List[Int]]
def pvl_add(a:Int,b:Int)->Int:return a+b
def pvl_identity(a:Int)->Int:return a
def pvl_value(fail:Bool,value:Int)->PVLawResult:
    if fail:
        var errors:List[Int]=[value]
        return Err(errors^)
    return Ok(value)

def pvl_equal(left:PVLawResult,right:PVLawResult) raises:
    assert_equal(left.is_ok(),right.is_ok())
    if left.is_ok(): assert_equal(left._ok().value,right._ok().value)
    else: assert_equal(left._err().value,right._err().value)

def main() raises:
    for mask in range(8):
        var a=pvl_value(Bool(mask&1),1)
        var b=pvl_value(Bool(mask&2),2)
        var c=pvl_value(Bool(mask&4),3)
        var left=a.copy().par_map_n((b.copy(),),pvl_add).par_map_n((c.copy(),),pvl_add)
        var right=a.copy().par_map_n((b.copy().par_map_n((c^,),pvl_add),),pvl_add)
        pvl_equal(left^,right^)
        pvl_equal(a.copy().par_map_n(Tuple(),pvl_identity),a.copy())
        pvl_equal(a.copy().par_map_n((PVLawResult(Ok(0)),),pvl_add),a^)
    print('parallel validation laws: ok')
