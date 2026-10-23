# error: no matching method in call to 'filter_map'
from fp.functions import piped
from fp.data import Result, Ok
def expansion_select(x: Int) -> Optional[Int]: return Optional(x)
def main():
    _ = piped(Result[Int, String](Ok(1))).filter_map(expansion_select).get()
