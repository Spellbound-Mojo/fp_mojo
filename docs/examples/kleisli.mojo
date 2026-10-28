"""One effectful function chain reused in eager and lazy pipelines."""
from fp.algebra import ResultFamily
from fp.data import Result, Ok, Err
from fp.functions import kleisli, pipeline
from fp.iteration import iterated
from std.testing import assert_equal, assert_true


def kleisli_parse(text: String) -> Result[Int, String]:
    try:
        return Ok(Int(text))
    except:
        return Err(String("expected an integer"))


def kleisli_validate(value: Int) -> Result[Int, String]:
    if value <= 0:
        return Err(String("expected a positive integer"))
    return Ok(value)


def kleisli_render(value: Int) -> String:
    return "accepted: " + String(value)


def main() raises:
    var chain = kleisli[ResultFamily[String]](kleisli_parse).then(kleisli_validate).map(kleisli_render)
    var values: List[String] = ["7", "-2", "oops"]
    var eager = pipeline(values^).map(chain).get()
    assert_equal(eager[0].copy().raise_on_err(), "accepted: 7")
    assert_true(eager[1].is_err())
    assert_true(eager[2].is_err())
    var more: List[String] = ["8", "9"]
    var lazy = iterated(more^).map(chain)
    for var result in lazy^:
        print(result^.raise_on_err())
    var all_values: List[String] = ["10", "11"]
    var gathered = pipeline(all_values^).traverse(chain).get()
    assert_equal(gathered^.raise_on_err(), ["accepted: 10", "accepted: 11"])
    print(pipeline(String("12")).then(chain).raise_on_err())
