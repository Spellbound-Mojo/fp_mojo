# error: no matching method in call to 'filter_map'
from fp.functions import pipeline
from fp.data import Result, Ok
def expansion_select(x: Int) -> Optional[Int]: return Optional(x)
def main():
    _ = pipeline(Result[Int, String](Ok(1))).filter_map(expansion_select).get()
