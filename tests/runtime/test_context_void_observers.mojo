from fp.functions import pipeline
from fp.data import Result, Err
from std.testing import assert_equal
@fieldwise_init
struct VoidObserveFault(Movable):
    var code: Int

def pure(value: Int): pass
def never(value: Int) raises Never: pass
def raising(value: Int) raises VoidObserveFault: raise VoidObserveFault(value)

def main() raises:
    assert_equal(pipeline(Result[String,Int](Err(3))).tap_err(pure).get()._err().value, 3)
    assert_equal(pipeline(Result[String,Int](Err(4))).tap_err(never).get()._err().value, 4)
    var called=0
    def captured(value:Int) {mut called}: called += value
    def captured_never(value:Int) raises Never {mut called}: called += value
    assert_equal(pipeline(Result[String,Int](Err(5))).tap_err(captured).get()._err().value, 5)
    assert_equal(pipeline(Result[String,Int](Err(6))).raising[VoidObserveFault]().tap_err(captured_never).get()._err().value, 6)
    var code=0
    try: _ = pipeline(Result[String,Int](Err(7))).raising[VoidObserveFault]().tap_err(raising).get()
    except error: code=error.code
    assert_equal(code, 7)
    assert_equal(called, 11)
