# error: constraint
from fp.functions import pipeline, piped
from fp.data import ControlFlow, Continue
from fluent_fold_support import Step, Once, Bare
def main():
    _ = piped(List[Int]()).fold_left(Once(1),0).get()
