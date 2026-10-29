# error: no matching
from fp.effects import lift_resource, pure_resource
def bad(value: Int) -> Int: return value
def main():
    var pointer: def(Int) thin -> Int = bad
    _ = lift_resource(pure_resource[Int](7)).eval_map(pointer)
