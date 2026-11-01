from context_map2_contract_support import immediate, delayed
from fp.algebra import IdentityFamily, OptionalFamily, ResultFamily
from algebra_support.box import BoxMonad
from std.testing import assert_equal

def main() raises:
    assert_equal(immediate[IdentityFamily,0,False,False](), "c92r3z")
    assert_equal(immediate[IdentityFamily,0,False,True](), "c219e7z")
    assert_equal(immediate[OptionalFamily,1,False,False](), "c92r3z")
    assert_equal(immediate[OptionalFamily,1,False,True](), "c219e7z")
    assert_equal(immediate[OptionalFamily,2,True,True](), "129rz")
    assert_equal(immediate[ResultFamily[String],2,False,False](), "c92r3z")
    assert_equal(immediate[ResultFamily[String],2,False,True](), "c219e7z")
    assert_equal(immediate[ResultFamily[String],0,True,True](), "192rz")
    assert_equal(immediate[BoxMonad,1,False,False](), "c92r3z")
    assert_equal(delayed[True,False](), "dc92r3z")
    assert_equal(delayed[True,True](), "dc219e7z")
    assert_equal(delayed[False,True](), "d192z")
