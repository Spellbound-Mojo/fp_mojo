# error: uninitialized
from fp.functions import pipeline
from fp.algebra import StringMonoid
def main():
    var values = pipeline(List[Optional[String]]())
    _ = values^.combine_all_effect[StringMonoid]()
    _ = values^.get()
