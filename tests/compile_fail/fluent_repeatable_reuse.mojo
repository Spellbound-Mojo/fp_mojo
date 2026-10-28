# error: use of uninitialized value 'step'
from fp.functions import pipeline, piped
from fp.data import ControlFlow, Continue
from fluent_fold_support import Step, Once, Bare
def main():
    var step = Step(1)
    _ = pipeline[Int]([1]).fold_left(step^,0).get()
    print(step.output)
