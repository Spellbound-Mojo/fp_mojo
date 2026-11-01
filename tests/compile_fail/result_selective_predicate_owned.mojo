# Mojo 1.2: bind C before checking the invalid native signature.
# Removing this hint reproduces a compiler crash; see native-boundaries.md.
# error: value passed to 'C' cannot be converted
# error: no matching method in call to 'recover_if'
from fp.data import Result, Err
@fieldwise_init
struct RSPRejectedError(Movable):
    var value: Int
def predicate(var error: RSPRejectedError) -> Bool: return error.value > 0
def recover(var error: RSPRejectedError) -> Int: return error.value
def main():
    _ = Result[Int, RSPRejectedError](Err(RSPRejectedError(1))).recover_if[C=type_of(predicate)](predicate, recover)
