# error: invalid call to 'map_err': lacking evidence to prove correctness
from fp.functions import pipeline
from fp.effects import ResultT, Reader

def reject(left:List[Int],right:List[Int]):
    comptime L=type_of(Span(left))
    comptime R=type_of(Span(right))
    comptime I=ResultT[Reader[Int],L]
    def changed(var error:L) {ref right}->R:return Span(right)
    _=pipeline[I](I.fail[Int](Span(left))).map_err[Target=I](changed)
def main():
    reject(List[Int]([1]),List[Int]([2]))
