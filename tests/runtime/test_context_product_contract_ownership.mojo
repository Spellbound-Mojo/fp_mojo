from context_product_contract_support import immediate, delayed
from fp.algebra import IdentityFamily, OptionalFamily, ResultFamily
from algebra_support.box import BoxMonad
from std.testing import assert_equal

def main() raises:
    assert_equal(immediate[IdentityFamily,0,False,False](), "r12z")
    assert_equal(immediate[OptionalFamily,1,False,False](), "r12z")
    assert_equal(immediate[OptionalFamily,2,True,False](), "12rz")
    assert_equal(immediate[OptionalFamily,2,False,True](), "21rz")
    assert_equal(immediate[ResultFamily[String],2,False,False](), "r12z")
    assert_equal(immediate[ResultFamily[String],0,True,False](), "12rz")
    assert_equal(immediate[ResultFamily[String],0,False,True](), "21rz")
    assert_equal(immediate[BoxMonad,1,False,False](), "r12z")
    assert_equal(delayed[True](), "dr12z")
    assert_equal(delayed[False](), "d12z")
