# error: compose: stage 1 (argument 1) must take one argument
from fp.functions import compose, Identity
def seven() -> Int: return 7
def plus(var value: Int) -> Int: return value + 1
def main(): _ = compose(Identity[Int](), seven).compose(plus)
