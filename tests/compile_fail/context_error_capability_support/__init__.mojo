"""Valid callbacks shared by capability rejection and acceptance controls."""
from fp.callables import Unary, BorrowCallable
from fp.data import Result, Ok

@fieldwise_init
struct Value[A: Movable & Deinitable](Unary):
    comptime Arg = Self.A
    comptime Out = Int
    def call(self, var value: Self.A) -> Int: return 7

@fieldwise_init
struct Effect[A: Movable & Deinitable, E: Movable & Deinitable](Unary):
    comptime Arg = Self.A
    comptime Out = Result[Int,Self.E]
    def call(self, var value: Self.A) -> Self.Out: return Ok(7)

@fieldwise_init
struct BorrowValue[A: Movable & Deinitable](BorrowCallable):
    comptime Payload = Self.A
    comptime Result = Int
    def invoke(self, ref value: Self.A) -> Int: return 7

@fieldwise_init
struct BorrowEffect[A: Movable & Deinitable](BorrowCallable):
    comptime Payload = Self.A
    comptime Result = Result[Int,String]
    def invoke(self, ref value: Self.A) -> Self.Result: return Ok(7)

@fieldwise_init
struct Predicate[A: Movable & Deinitable](BorrowCallable):
    comptime Payload = Self.A
    comptime Result = Bool
    def invoke(self, ref value: Self.A) -> Bool: return True

@fieldwise_init
struct MakeError(BorrowCallable):
    comptime Payload = Int
    comptime Result = String
    def invoke(self, ref value: Int) -> String: return String("invalid")

def recover(var error: String) -> Int: return error.byte_length()
def effect(var error: String) -> Result[Int,String]: return Ok(error.byte_length())
def changed_effect(var error: String) -> Result[Int,Int]: return Ok(error.byte_length())
def observe(error: String) -> Int: return error.byte_length()
def observe_effect(error: String) -> Result[Int,String]: return Ok(error.byte_length())
def choose(error: String) -> Bool: return True
def positive(value: Int) -> Bool: return value > 0
def invalid(value: Int) -> String: return String("invalid")
def increment(var value: Int) -> Int: return value + 1
def increment_effect(var value: Int) -> Result[Int,String]: return Ok(value + 1)
def changed_increment_effect(var value: Int) -> Result[Int,Int]: return Ok(value + 1)
def whole(outcome: Result[Int,String]) -> Result[Int,String]: return Ok(7)
