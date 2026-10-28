# error: pipe: stage 1 should take type_of(None) (no return value)
# error: it takes std.builtin.none.NoneType
from fp.functions import pipe, Identity
def native(var value: Int): _ = value
def main(): pipe(3, native, Identity[NoneType]())
