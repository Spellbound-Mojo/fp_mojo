# error: uninitialized
from fp.callables import BorrowMutableCallable
from fp.effects import Reader,run
from fp.functions import pipeline
@fieldwise_init
struct Inspect(BorrowMutableCallable):
    comptime Payload=Int
    comptime Result=Int
    var label:String
    def invoke_mut(mut self,ref value:Int)->Int:return self.label.byte_length()+value
def main():
    comptime R=Reader[Int]
    var callback=Inspect(String('state'))
    var pending=pipeline[R](R.pure(1)).tap_each(callback^).get()
    var value=2
    _=callback.invoke_mut(value)
    _=run[R](pending^,0)
