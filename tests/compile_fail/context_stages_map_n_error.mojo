# error: no matching method in call to 'map_n'
from fp.functions import pipeline
from fp.data import Result, Ok
def add(var a: Int, var b: Int) -> Int: return a + b
def main(): _ = pipeline(Result[Int, String](Ok(1))).map_n((Result[Int, Int](Ok(2)),), add).get()
