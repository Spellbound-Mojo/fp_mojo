# error: constraint
from fp.functions import pipeline
from fp.data import ControlFlow, Continue
from fluent_fold_support import Step, Once, Bare
def main():
    _ = pipeline[Int]([1]).fold_left(Step[Int,Never,Int,String](1),0).get()
