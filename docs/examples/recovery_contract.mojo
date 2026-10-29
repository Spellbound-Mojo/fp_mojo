"""One public signature for immediate and deferred value-returning recovery."""
from fp.algebra import ApplicativeError, RecoverContract, ResultFamily
from fp.callables import UnaryContract, Unary
from fp.data import Result, Err
from fp.effects import Reader, ResultT, run
from fp.functions import piped


def recovered[I: ApplicativeError, V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](
    var value: V, var handler: H
) raises RecoverContract[I, V, H].Error -> RecoverContract[I, V, H].Out where RecoverContract[I, V, H].Compatible:
    return piped(value^).recover[I](handler^).get()


@fieldwise_init
struct Length(Unary):
    comptime Arg = String
    comptime Out = Int
    def call(self, var error: String) -> Int:
        return error.byte_length()


def main() raises:
    var immediate = recovered[ResultFamily[String]](Result[Int, String](Err(String("lost"))), Length())
    print("recovered:", immediate^.raise_on_err())

    comptime Environment = Reader[Int]
    comptime Deferred = ResultT[Environment, String]
    var pending = recovered[Deferred](Deferred.fail[Int](String("offline")), Length())
    print("deferred:", run[Environment](pending^, 0).raise_on_err())
