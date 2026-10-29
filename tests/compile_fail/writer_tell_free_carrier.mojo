# error: violated constraint
from fp.effects import Writer, tell
from fp.algebra import StringMonoid
def main(): _ = tell[Writer[StringMonoid]]("a",Optional(7))
