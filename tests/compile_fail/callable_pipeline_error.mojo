# error: pipe: stage 0 should take Int, return Int and raise callable_pipeline_error.Second or nothing
# error: raises callable_pipeline_error.First
from fp.functions import pipe, as_unary
from std.builtin.variadics import TypeList
@fieldwise_init
struct First(Copyable):
    var code: Int
@fieldwise_init
struct Second(Copyable):
    var code: Int
def fail(var value: Int) raises First -> Int: raise First(value)
def main():
    comptime Path = TypeList.of[Trait=Movable & Deinitable, Int]()
    var a = as_unary(fail)
    try: _ = pipe[Path, Second](1, a)
    except: pass
