from fp.algebra import map, ResultFamily
# error: use of uninitialized value 'value'
from fp.data import Result, Ok

def fail(var value: Int) raises Int -> Int:
    raise value

def main():
    var value = Result[Int, Int](Ok(1))
    try:
        _ = map[ResultFamily[type_of(value).Error]](fail, value^)
    except:
        pass
    _ = value.is_ok()
