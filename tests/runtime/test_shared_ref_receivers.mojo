"""Shared references select shared receivers without consuming their owners."""
from fp.callables import shared_ref,SharedRef,call_once,mut_ref
from fp.data import Capture, Result, Ok, Err
from fp.functions import pipeline
from test_attempt_once_receivers import Modes
from test_result_fold_receivers import Modes as UnaryModes
from std.testing import assert_equal

def main() raises:
    var factory=Modes(0)
    assert_equal(Capture().run(shared_ref(factory)).get_or(0),1)
    assert_equal(call_once(shared_ref(factory)),1)
    assert_equal(call_once(mut_ref(factory)),2)
    assert_equal(factory.calls,1)
    var callback=UnaryModes(0)
    assert_equal(Result[Int,Int](Ok(4)).fold(shared_ref(callback),shared_ref(callback)),1)
    assert_equal(Result[Int,Int](Ok(4)).fold_owned(shared_ref(callback),shared_ref(callback)),1)
    assert_equal(pipeline(Optional(4)).map(shared_ref(callback)).get_or(0),1)
    assert_equal(callback.calls,0)
