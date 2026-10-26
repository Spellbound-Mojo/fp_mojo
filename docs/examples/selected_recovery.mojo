"""Recover within a selected family and continue the same fluent pipeline."""
from fp.algebra import Functor, ApplicativeError
from fp.callables import UnaryContract, Unary
from fp.data import Result, Err, Ok
from fp.effects import Reader, ResultT, run
from fp.functions import Pipeline, pipeline, OrElseContract


def handled[I: Functor, V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](
    var value: V, var handler: H
) raises OrElseContract[I,V,H].Error -> Pipeline[OrElseContract[I,V,H].Family, OrElseContract[I,V,H].Out] where OrElseContract[I,V,H].Compatible:
    return pipeline[I](value^).or_else(handler^)


@fieldwise_init
struct Fallback[I: ApplicativeError](Unary):
    comptime Arg = Self.I.Failure
    comptime Out = Self.I.Pure[Int]
    def call(self, var error: Self.Arg) -> Self.Out:
        return Self.I.pure(9)


def length(var error: String) -> Int:
    return error.byte_length()


def changed(var error: String) -> Result[Int, Int]:
    return Ok(error.byte_length())


def double(var value: Int) -> Int:
    return value * 2


def main() raises:
    var immediate = pipeline(Result[Int,String](Err(String("retry")))).or_else(changed).get()
    comptime assert type_of(immediate) == Result[Int,Int]
    print("changed error:", immediate._ok().value)

    comptime Environment = Reader[Int]
    comptime Deferred = ResultT[Environment,String]
    var pending = pipeline[Deferred](Deferred.fail[Int](String("offline"))).recover(length).map(double).get()
    print("deferred:", run[Environment](pending^,0)._ok().value)

    var generic = handled[Deferred](Deferred.fail[Int](String("retry")),Fallback[Deferred]()).get()
    print("generic effect:", run[Environment](generic^,0)._ok().value)
