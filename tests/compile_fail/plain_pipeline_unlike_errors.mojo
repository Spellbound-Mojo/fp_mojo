# error: pipe: stage 1 should take Int, return Int and raise plain_pipeline_unlike_errors.First or nothing
# error: raises plain_pipeline_unlike_errors.Second
from fp.functions import pipe

@fieldwise_init
struct First(Movable, Writable):
    var code: Int

@fieldwise_init
struct Second(Movable, Writable):
    var code: Int

def one(value: Int) raises First -> Int:
    return value

def two(value: Int) raises Second -> Int:
    return value

def main() raises:
    _ = pipe(3, one, two)
