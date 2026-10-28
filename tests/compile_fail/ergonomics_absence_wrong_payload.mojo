# error: no matching
from fp.algebra import IdentityFamily, or_else_absent
def wrong() -> Optional[String]: return Optional(String("bad"))
def main(): _ = or_else_absent[IdentityFamily](wrong, Optional(1))
