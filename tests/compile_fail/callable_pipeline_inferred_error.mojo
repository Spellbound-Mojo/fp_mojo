# error: pipe: stage 1 should take Int, return Int and raise callable_pipeline_inferred_error.First or nothing
# error: raises callable_pipeline_inferred_error.Second
from fp.functions import pipe, as_unary
@fieldwise_init
struct First(Copyable):
    var code: Int
@fieldwise_init
struct Second(Copyable):
    var code: Int
def first(var value: Int) raises First -> Int: return value
def second(var value: Int) raises Second -> Int: raise Second(value)
def main():
    var a = as_unary(first)
    var b = as_unary(second)
    try: _ = pipe[E=First](1, a, b)
    except: pass
