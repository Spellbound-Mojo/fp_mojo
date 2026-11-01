# error: use of uninitialized value 'step'
from fp.control import fori_loop
from fluent_fold_support import Step, Once, Bare
def main():
    var step = Step(1)
    _ = fori_loop(0,0,step^,0)
    print(step.output)
