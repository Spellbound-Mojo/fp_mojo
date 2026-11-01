# Canonical Result pipelines may change the stored-error type in or_else;
# other ErrorRecovery families, such as ResultT over ListFamily, retain it.
# error: no matching method in call to 'or_else'
# error: violated constraint
from fp.algebra import ListFamily, fail
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from fp.effects import ResultT
def restore(var error: String) -> List[Result[Int, Int]]: return [Result[Int, Int](Err(1))]
def main():
    comptime F = ResultT[ListFamily, String]
    _ = pipeline[F](fail[F, Int](String("bad"))).or_else(restore).get()
