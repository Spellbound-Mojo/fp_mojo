# error: no matching method in call to 'min_by'
from fp.callables import BorrowOnceCallable
from fp.iteration import min_by,max_by,minimum_by_non_empty,maximum_by_non_empty,pair_with,tap_each,iterated
from fp.functions import pipeline
from fp.data import NonEmptyList
struct Once(BorrowOnceCallable):
    comptime Payload=Int
    comptime Result=Int
    def __init__(out self):pass
    def invoke_once(deinit self,ref value:Int)->Int:return value
def main() raises:_=pipeline(List[Int]([1,2,3])).min_by(Once())
