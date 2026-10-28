# error: no matching
from fp.effects import Ref
def leak[o:ImmOrigin](ref[o] value:List[Int])->Span[Int,o]:return Span(value)
def main():
    var state=Ref(List[Int]([1]))
    _=state.inspect[Error,F=type_of(leak)](leak)
