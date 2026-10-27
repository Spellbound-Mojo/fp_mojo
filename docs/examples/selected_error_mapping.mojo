"""Map stored errors while retaining the destination family's policy."""
from fp.algebra import Semigroup, ValidationFamily, ListMonoid, ResultFamily
from fp.data import Result, Ok, Err
from fp.functions import pipeline


struct Messages(Semigroup):
    comptime Value = String
    @staticmethod
    def combine(var left: String, var right: String) -> String:
        return left + "; " + right


def display(var value: Int) -> String: return String(value)
def error_code(var error: String) -> Int: return error.byte_length()
def add(var left: Int, var right: Int) -> Int: return left + right

def format_errors(var errors: List[String]) -> String:
    var text = String()
    for error in errors:
        if text.byte_length() > 0: text += "; "
        text += error
    return text^


def main():
    var changed = pipeline(Result[Int,String](Err(String("missing")))).map_both(display,error_code)
    comptime assert type_of(changed).I == ResultFamily[Int]
    print("error code:", changed^.get()._err().value)

    comptime Source = ValidationFamily[ListMonoid[String]]
    comptime Target = ValidationFamily[Messages]
    var original = Result[Int,List[String]](Err(List[String](["name missing"])))
    var mapped = pipeline[Source](original^).map_err[Target=Target](format_errors)
    comptime assert type_of(mapped).I == Target
    var combined = mapped^.map_n((Result[Int,String](Err(String("age invalid"))),), add).get()
    print("validation:", combined._err().value)
