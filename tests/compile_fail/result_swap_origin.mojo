# error: origin_of(local)
from fp.data import Result, Err
from fp.functions import pipeline
def check(anchor: List[Int], local: List[Int]):
    var view = Span(local)
    var other = Span(anchor)
    var bad: Result[type_of(other), Int] = pipeline(Result[Int, type_of(view)](Err(view))).swap().get()
    _ = bad^
def main():
    var a: List[Int] = [1]
    var b: List[Int] = [2]
    check(a, b)
