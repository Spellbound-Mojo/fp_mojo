# error: constraint
from fp.functions import pipeline
from fp.data import ControlFlow, Continue
from fluent_fold_support import Step, Once, Bare
def main():
    _ = pipeline[Int]([]).fold_until(Once(ControlFlow[Int,Int](Continue(1))),0).get()
