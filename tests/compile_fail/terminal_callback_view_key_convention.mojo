# error: no matching method
from fp.functions import as_unary, piped
from std.memory import ArcPointer
@fieldwise_init
struct Value(Movable):
    var value: Int
    var state: ArcPointer[Int]
def key(var value: Value) -> Int: return value.value
def main():
    var project = as_unary(key)
    _ = piped(List[Value]()).min_by(project).get()
