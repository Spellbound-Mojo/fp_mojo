# error: no matching method in call to 'traverse'
from fp.algebra import OptionalFamily,ResultFamily
from fp.effects import Reader
from fp.functions import pipeline
from fp.data import Result,Ok
from context_traversal_admission_support import OnceNext

def main() raises:
    comptime I=Reader[Int]
    _=pipeline[ResultFamily[String]](Result[Int,String](Ok(1))).traverse[I](OnceNext[I]()).get()
