"""Change a selected inner error while preserving outer effects and branch order."""
from fp.algebra import ListFamily, ResultFamily
from fp.effects import ResultT, OptionalT
from fp.data import Result, Ok, Err
from fp.functions import pipeline


def value(var number: Int) -> Int:
    print("value:", number)
    return number * 10

def failure(var message: String) -> Int:
    print("error:", message)
    return message.byte_length()


def number(value: Int) -> Int:
    return value


def main():
    comptime I = ResultT[ListFamily,String]
    var inputs = List[Result[Int,String]]([Result[Int,String](Err(String("first"))), Result[Int,String](Ok(2)), Result[Int,String](Err(String("last")))])
    var mapped = pipeline[I](inputs^).map_both(value,failure)
    comptime assert type_of(mapped).I == ResultT[ListFamily,Int]
    var outputs = mapped^.get()
    print("outputs:", outputs[0].fold(number, number), outputs[1].fold(number, number), outputs[2].fold(number, number))

    comptime OptionalErrors = OptionalT[ResultFamily[String]]
    var absent = Result[Optional[Int],String](Ok(Optional[Int]()))
    var kept = pipeline[OptionalErrors](absent^).map_both(value,failure)
    comptime assert type_of(kept).I == OptionalT[ResultFamily[Int]]
    print("still absent:", not Bool(kept^.get().to_optional().value()))
