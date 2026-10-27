"""Proven non-error selected families preserve intrinsic Result forwarding."""
from fp.functions import pipeline
from fp.algebra import Functor, ApplicativeError, ErrorMapping, IdentityFamily, ResultFamily
from fp.data import Result, Ok, Err
from std.testing import assert_equal

def forwarded[A: Movable & Deinitable, E1: Movable & Deinitable, E2: Movable & Deinitable, o: ImmOrigin, //, I: Functor, F: def(var E1) -> Result[A,E2]](var source: Result[A,E1], ref[o] handler: F) -> Result[A,E2] where not conforms_to(I, ApplicativeError) and not conforms_to(I, ErrorMapping):
    return pipeline[I](source^).or_else(handler).get()

def changed(var error: String) -> Result[Int,Int]: return Ok(error.byte_length())
def unchanged(var error: String) -> Result[Int,String]: return Ok(error.byte_length())
def main() raises:
    assert_equal(forwarded[IdentityFamily](Result[Int,String](Err(String("four"))),changed)._ok().value,4)
    assert_equal(forwarded[IdentityFamily](Result[Int,String](Err(String("three"))),unchanged)._ok().value,5)
