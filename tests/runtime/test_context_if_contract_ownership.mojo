from context_if_contract_support import immediate, branched, deferred
from fp.algebra import IdentityFamily, OptionalFamily, ResultFamily
from std.testing import assert_equal

def main() raises:
    assert_equal(immediate[OptionalFamily,0,True,False,False](), "2c111rz")
    assert_equal(immediate[OptionalFamily,1,False,False,False](), "1c212rz")
    assert_equal(immediate[OptionalFamily,2,True,True,False](), "12rz")
    assert_equal(immediate[OptionalFamily,0,True,False,True](), "2c111e7z")
    assert_equal(immediate[OptionalFamily,1,False,False,True](), "1c212e7z")
    assert_equal(immediate[IdentityFamily,2,True,False,False](), "2c111rz")
    assert_equal(immediate[ResultFamily[String],0,True,True,True](), "12rz")
    assert_equal(immediate[ResultFamily[String],1,False,False,False](), "1c212rz")
    assert_equal(branched(), "c11c21c1212v11v21v12z")
    assert_equal(deferred[True,False](), "d2c111v11z")
    assert_equal(deferred[True,True](), "d2c111e7z")
    assert_equal(deferred[False,True](), "d12z")
