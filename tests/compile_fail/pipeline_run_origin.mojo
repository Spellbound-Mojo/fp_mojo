# error: lacking evidence
from fp.functions import pipeline
from fp.effects import Reader
from context_reader_run_support import Produce
def main():
    var first = 1
    var second = 2
    var pending = pipeline(Reader[Int].collect(Produce(Pointer(to=first)), List[Int]([1])))
    try:
        _ = pending^.run(second)
    except error:
        pass
