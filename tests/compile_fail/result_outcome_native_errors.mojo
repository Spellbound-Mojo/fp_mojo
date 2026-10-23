# error: constraint
from fp.data import Result, Ok
def on_ok(value: Int) raises Int -> Int: raise value
def on_err(var error: String) raises String -> Int: raise error^
def main():
    try: _ = Result[Int, String](Ok(1)).map_both(on_ok, on_err)
    except error: pass
