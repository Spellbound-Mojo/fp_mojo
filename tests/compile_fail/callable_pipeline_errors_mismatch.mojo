# error: pipe: stage 3 should take Int, return Int and raise callable_pipeline_errors_mismatch.First or nothing
# error: raises callable_pipeline_errors_mismatch.Second
from fp.functions import pipe, as_unary
@fieldwise_init
struct First(Copyable):
    var code: Int
@fieldwise_init
struct Second(Copyable):
    var code: Int
def first(var value: Int) raises First -> Int: return value
def second(var value: Int) raises Second -> Int: raise Second(value)
def neutral(var value: Int) raises Never -> Int: return value
def main():
    var a = as_unary(first)
    var b = as_unary(second)
    var p = as_unary(neutral)
    try: _ = pipe(1, a, p, p, b)
    except: pass
