# error: constraint
from fp.iteration import sequence_filter
from fp.algebra import OptionalFamily
def main():
    var xs:List[Optional[Int]]=[Optional(1)]
    _=sequence_filter[OptionalFamily](xs^)
