from context_ap_contract_support import immediate, delayed
from fp.algebra import IdentityFamily, OptionalFamily, ResultFamily
from algebra_support.box import BoxMonad
from std.testing import assert_equal

def main() raises:
    assert_equal(immediate[IdentityFamily,0,False,False,False](), "c9r2z")
    assert_equal(immediate[IdentityFamily,2,False,False,True](), "c29e7z")
    assert_equal(immediate[OptionalFamily,1,False,False,False](), "c9r2z")
    assert_equal(immediate[OptionalFamily,2,True,False,False](), "92rz")
    assert_equal(immediate[OptionalFamily,2,False,True,False](), "29rz")
    assert_equal(immediate[OptionalFamily,1,False,False,True](), "c29e7z")
    assert_equal(immediate[ResultFamily[String],2,False,False,False](), "c9r2z")
    assert_equal(immediate[ResultFamily[String],0,True,False,False](), "92rz")
    assert_equal(immediate[ResultFamily[String],0,False,True,False](), "29rz")
    assert_equal(immediate[ResultFamily[String],1,False,False,True](), "c29e7z")
    assert_equal(immediate[BoxMonad,1,False,False,False](), "c9r2z")
    assert_equal(immediate[BoxMonad,0,False,False,True](), "c29e7z")
    assert_equal(delayed[True,False](), "dc9r2z")
    assert_equal(delayed[True,True](), "dc29e7z")
    assert_equal(delayed[False,False](), "d92z")
