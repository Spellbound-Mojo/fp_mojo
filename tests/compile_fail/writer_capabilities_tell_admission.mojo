# error: constraint
from fp.effects import Tell, Writer, tell
from fp.algebra import StringMonoid
def emit[C: Tell](var log: C.Log.Value) raises C.TellError -> C.Told:
    return tell[C](log^)
def main(): _ = emit[Writer[StringMonoid]](String("a"))
