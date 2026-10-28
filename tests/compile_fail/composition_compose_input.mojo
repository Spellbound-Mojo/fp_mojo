# error: flow: stage 1 should take String
# error: it takes Int
from fp.functions import flow, Identity
def text(var value: Int) -> String: return String(value)
def main(): _ = flow(Identity[Int](), Identity[Int]()).compose(text)
