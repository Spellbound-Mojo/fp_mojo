"""The stage seed, step, inputs and native errors retain their cleanup order."""
from context_staged_fold_contract_support import immediate, delayed, abandoned_stage
from fp.algebra import IdentityFamily, OptionalFamily, ResultFamily
from algebra_support.box import BoxMonad
from std.testing import assert_equal

def main() raises:
    assert_equal(immediate[IdentityFamily, False](), "p1p2p39r0123z")
    assert_equal(immediate[IdentityFamily, True](), "p1p220193e77z")
    assert_equal(immediate[OptionalFamily, False](), "p1p2p39r0123z")
    assert_equal(immediate[OptionalFamily, True](), "p1p220193e77z")
    assert_equal(immediate[ResultFamily[String], False](), "p1p2p39r0123z")
    assert_equal(immediate[ResultFamily[String], True](), "p1p220193e77z")
    assert_equal(immediate[BoxMonad, False](), "p1p2p39r0123z")
    assert_equal(immediate[BoxMonad, True](), "p1p220193e77z")
    assert_equal(delayed[False, True](), "dp1p2p39r0123z")
    assert_equal(delayed[True, True](), "dp1p220193e77z")
    assert_equal(delayed[False, False](), "d90123z")
    assert_equal(abandoned_stage(), "d1230")
