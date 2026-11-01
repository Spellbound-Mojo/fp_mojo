# error: flow: stage 1 should take type_of(None) (no return value)
# error: it takes std.builtin.none.NoneType
from fp.functions import flow, Identity
def discard(var value: Int): _ = value
def main(): _ = flow(Identity[NoneType](), Identity[NoneType]()).compose(discard)
