# error: no matching method in call to 'traverse'
from fp.algebra import IdentityFamily, OptionalFamily, ResultFamily, ListFamily, StringMonoid
from fp.effects import WriterT
from fp.functions import pipeline
from context_branch_admission_support import OnceNext

comptime W=WriterT[IdentityFamily,StringMonoid]

def main() raises:
    _=pipeline(List[Int]([1,2])).traverse[W](OnceNext[W]()).get()
