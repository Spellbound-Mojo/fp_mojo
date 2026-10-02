from fp.algebra import flat_map, ResultFamily
# error: invalid call to 'and_then_raising2': lacking evidence to prove correctness
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
def and_then_raising1[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var T) raises X -> Result[U, E]](var value: Result[T, E], callback: F) raises X -> Result[U, E]:
    return flat_map[ResultFamily[type_of(value).Error], X=X](callback, value^)
def and_then_raising2[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable, //, F: def(var T) raises X -> Result[U, E]](var value: Result[T, E], callback: F) raises X -> Result[U, E]:
    return and_then_raising1[X=X](value^, callback)

def wrong(first: List[Int], second: List[Int]):
    var a = Span(first)
    var b = Span(second)
    comptime A = type_of(a)
    comptime B = type_of(b)
    print(a[0], b[0])
    try:
        _ = and_then_raising2[T=A, E=Int, U=B, X=A](Result[A, Int](Ok(a)), success_raising[A, Int, A])
    except: pass

def main():
    var first: List[Int] = [11]
    var second: List[Int] = [22]
    wrong(first, second)
