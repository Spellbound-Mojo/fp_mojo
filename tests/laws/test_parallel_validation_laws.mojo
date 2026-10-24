"""Accumulating Result composition respects associativity and pure identity."""
from fp.functions import piped
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
        var left=piped(a.copy()).par_map_n((b.copy(),),pvl_add).par_map_n((c.copy(),),pvl_add).get()
        var right=piped(a.copy()).par_map_n((piped(b.copy()).par_map_n((c^,),pvl_add).get(),),pvl_add).get()
        pvl_equal(left,right)
        pvl_equal(piped(a.copy()).par_map_n(Tuple(),pvl_identity).get(),a.copy())
        pvl_equal(piped(a.copy()).par_map_n((PVLawResult(Ok(0)),),pvl_add).get(),a)
    print('parallel validation laws: ok')
