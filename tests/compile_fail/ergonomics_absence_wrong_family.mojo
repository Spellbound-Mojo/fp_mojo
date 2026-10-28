# error: no matching
from fp.algebra import ResultFamily, or_else_absent
def wrong() -> Optional[Int]: return Optional(2)
def main(): _ = or_else_absent[ResultFamily[String]](wrong, ResultFamily[String].pure(Optional(1)))
