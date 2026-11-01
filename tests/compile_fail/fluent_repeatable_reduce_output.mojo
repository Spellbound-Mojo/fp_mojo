# error: constraint
from fp.functions import pipeline
from fp.data import ControlFlow, Continue
from fluent_fold_support import Step, Once, Bare
def main():
    _ = pipeline[List[Int]]([1]).reduce_optional(Step(String("bad"))).get()
