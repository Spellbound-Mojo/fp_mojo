# error: invalid call to 'or_else_pure2': lacking evidence to prove correctness
from fp.data import Result, Ok, Err

def identity[T: Movable & Deinitable](var value: T) -> T: return value^
def raising[T: Movable & Deinitable, X: Movable & Deinitable](var value: T) raises X -> T: return value^
def success[T: Movable & Deinitable, E: Movable & Deinitable](var value: T) -> Result[T, E]: return Result[T, E](Ok(value^))
def recovery[T: Movable & Deinitable, E: Movable & Deinitable](var value: E) -> Result[T, E]: return Result[T, E](Err(value^))
def success_raising[T: Movable & Deinitable, E: Movable & Deinitable, X: Movable & Deinitable](var value: T) raises X -> Result[T, E]: return Result[T, E](Ok(value^))
def recovery_raising[T: Movable & Deinitable, E: Movable & Deinitable, X: Movable & Deinitable](var value: E) raises X -> Result[T, E]: return Result[T, E](Err(value^))

def count[T: Movable & Deinitable](var value: T) -> Int: return 1
def count_raising[T: Movable & Deinitable, X: Movable & Deinitable](var value: T) raises X -> Int: return 1
def success_count[T: Movable & Deinitable, E: Movable & Deinitable](var value: T) -> Result[Int, E]: return Result[Int, E](Ok(1))
def success_count_raising[T: Movable & Deinitable, E: Movable & Deinitable, X: Movable & Deinitable](var value: T) raises X -> Result[Int, E]: return Result[Int, E](Ok(1))
def recovery_count[T: Movable & Deinitable, E: Movable & Deinitable](var value: E) -> Result[T, Int]: return Result[T, Int](Err(1))
def recovery_count_raising[T: Movable & Deinitable, E: Movable & Deinitable, X: Movable & Deinitable](var value: E) raises X -> Result[T, Int]: return Result[T, Int](Err(1))
def or_else_pure1[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, //, F: def(var E) -> Result[T, U]](var value: Result[T, E], callback: F) -> Result[T, U]:
    return value^.or_else(callback)
def or_else_pure2[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, //, F: def(var E) -> Result[T, U]](var value: Result[T, E], callback: F) -> Result[T, U]:
    return or_else_pure1(value^, callback)

def wrong(first: List[Int], second: List[Int]):
    var a = Span(first)
    var b = Span(second)
    comptime A = type_of(a)
    comptime B = type_of(b)
    print(a[0], b[0])
    _ = or_else_pure2[T=Int, E=A, U=Int](Result[Int, A](Err(a)), recovery_count[Int, B])

def main():
    var first: List[Int] = [11]
    var second: List[Int] = [22]
    wrong(first, second)
