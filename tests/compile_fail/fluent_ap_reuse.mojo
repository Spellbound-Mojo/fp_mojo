from fp.functions import piped
# error: use of uninitialized value 'values'
from fp.data import Result, Ok
from fp.callables import as_unary
def increment(x: Int) -> Int: return x+1
def main():
    var function = as_unary(increment)
    var values = Result[Int,String](Ok(1))
    _ = piped(Result[type_of(function),String](Ok(function^))).ap(values^).get()
    print(values.is_ok())
