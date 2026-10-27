# error: no matching method in call to 'traverse'
from fp.algebra import IdentityFamily,OptionalFamily,ResultFamily,ValidationFamily,ListMonoid
from fp.functions import pipeline
from context_branch_admission_support import OnceNext

def main() raises:
    _=pipeline(List[Int]([1,2])).traverse[ResultFamily[String]](OnceNext[ResultFamily[String]]()).get()
