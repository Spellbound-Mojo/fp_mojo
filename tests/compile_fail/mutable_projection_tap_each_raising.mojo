# error: no matching function in call to 'tap_each'
from fp.callables import BorrowMutableCallable
from fp.iteration import min_by,max_by,minimum_by_non_empty,maximum_by_non_empty,pair_with,tap_each,iterated
from fp.functions import piped,pipeline
from fp.data import NonEmptyList
struct Raising(BorrowMutableCallable):
    comptime Payload=Int
    comptime Result=Int
    comptime Failure=Int
    def __init__(out self):pass
    def invoke_mut(mut self,ref value:Int) raises Int -> Int:raise value
def main() raises:_=tap_each(range(3),Raising())
