# error: no matching function in call to 'min_by'
from fp.callables import BorrowMutableCallable
from fp.iteration import min_by,max_by,minimum_by_non_empty,maximum_by_non_empty,pair_with,tap_each,iterated
from fp.functions import piped,pipeline
from fp.data import NonEmptyList
struct Wrong(BorrowMutableCallable):
    comptime Payload=String
    comptime Result=Int
    def __init__(out self):pass
    def invoke_mut(mut self,ref value:String)->Self.Result:return 1
def main() raises:_=min_by(range(3),Wrong())
