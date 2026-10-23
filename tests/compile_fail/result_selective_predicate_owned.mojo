# error: no matching method in call to 'recover_if'
from fp.data import Result, Err
@fieldwise_init
struct RSPRejectedError(Movable):
    var value: Int
def predicate(var error: RSPRejectedError) -> Bool: return error.value > 0
def recover(var error: RSPRejectedError) -> Int: return error.value
def main():
    _ = Result[Int, RSPRejectedError](Err(RSPRejectedError(1))).recover_if(predicate, recover)
