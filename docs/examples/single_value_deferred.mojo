"""A present input prepares a Reader; running it supplies the environment."""
from fp.callables import BorrowOnceCallable
from fp.effects import Reader,action,run
from fp.functions import pipeline
from std.testing import assert_equal

comptime R=Reader[Int]

@fieldwise_init
struct AddEnvironment(BorrowOnceCallable):
    var number:Int
    comptime Payload=Int
    comptime Result=Int
    def invoke_once(deinit self,ref environment:Int)->Int:
        return self.number+environment

def prepare(var number:Int)->R.Endpoint[Int,AddEnvironment]:
    return action[R,Int](AddEnvironment(number))

def main() raises:
    # Traversal calls prepare now. AddEnvironment waits for run.
    var pending=pipeline(Optional(7)).traverse[R](prepare).get()
    var environment=10
    var answer=run[R](pending^,environment)
    assert_equal(answer.value(),17)
    # Absence skips prepare and remains absent when the Reader runs.
    var skipped=pipeline(Optional[Int]()).traverse[R](prepare).get()
    var absent=run[R](skipped^,environment)
    assert_equal(Bool(absent),False)
    print("deferred single traversal: answer=",answer.value(),"; absent=",not Bool(absent),sep="")
