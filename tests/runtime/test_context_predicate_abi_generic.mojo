"""Predicate result equality preserves generic native ABI and explicit bindings."""
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from std.testing import assert_equal


# The return type remains symbolic while its native register ABI is known.
# Positional [F] binds the second callback, as it did before ABI pruning.
def ensure_forward[A: TrivialRegisterPassable, R: RegisterPassable & Deinitable, F: def(A) -> String](var source: Result[A,String], predicate: def(A) thin -> R, factory: F) -> Result[A,String] where R == Bool:
    return pipeline(source^).ensure[F](predicate,factory).get()


def recover_forward[A: Movable & Deinitable, E: TrivialRegisterPassable, R: RegisterPassable & Deinitable, F: def(var E) -> A](var source: Result[A,E], predicate: def(E) thin -> R, handler: F) -> Result[A,E] where R == Bool:
    return pipeline(source^).recover_if[F](predicate,handler).get()


def else_forward[A: Movable & Deinitable, E: TrivialRegisterPassable, R: RegisterPassable & Deinitable, F: def(var E) -> Result[A,E]](var source: Result[A,E], predicate: def(E) thin -> R, handler: F) -> Result[A,E] where R == Bool:
    return pipeline(source^).or_else_if[F](predicate,handler).get()


def raising_forward[A: TrivialRegisterPassable, R: RegisterPassable & Deinitable, X: Movable & Deinitable, F: def(A) -> String](var source: Result[A,String], predicate: def(A) raises X thin -> R, factory: F) raises X -> Result[A,String] where R == Bool:
    return pipeline(source^).raising[X]().ensure[F](predicate,factory).get()


def reject(value: Int) -> Bool: return False
def accept(value: Int) -> Bool: return True
def label(value: Int) -> String: return String(value)
def restored(var value: Int) -> String: return String(value)
def effect(var value: Int) -> Result[String,Int]: return Ok(String(value))
def never_reject(value: Int) raises Never -> Bool: return False
def raised(value: Int) raises Int -> Bool: raise value
def reject_text(value: String) -> Bool: return False
def length(value: String) -> Int: return value.byte_length()


def main() raises:
    comptime assert conforms_to(Bool, RegisterPassable)
    var no: def(Int) thin -> Bool = reject
    var yes: def(Int) thin -> Bool = accept
    assert_equal(ensure_forward(Result[Int,String](Ok(4)),no,label)._err().value,"4")
    assert_equal(recover_forward(Result[String,Int](Err(5)),yes,restored)._ok().value,"5")
    assert_equal(else_forward(Result[String,Int](Err(6)),yes,effect)._ok().value,"6")
    var never: def(Int) raises Never thin -> Bool = never_reject
    assert_equal(raising_forward(Result[Int,String](Ok(7)),never,label)._err().value,"7")
    var fail: def(Int) raises Int thin -> Bool = raised
    var code = 0
    try: _ = raising_forward(Result[Int,String](Ok(8)),fail,label)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,8)
    # Memory-passed predicate inputs and named result bindings remain distinct
    # from the register-input boundary used by the generic forwards above.
    var text: def(String) thin -> Bool = reject_text
    assert_equal(pipeline(Result[String,Int](Ok(String("word")))).ensure[R=Bool](text,length).get()._err().value,4)
