"""Parse, collect, total and combine with one native error selection."""
from fp.functions import pipeline
from fp.algebra import ResultFamily
from fp.data import Result, Ok, Err
from std.testing import assert_equal

@fieldwise_init
struct WorkflowTransportFailure(Movable):
    var status: Int

def parse(var text: String) raises WorkflowTransportFailure -> Result[Int, String]:
    if text == "offline": raise WorkflowTransportFailure(503)
    var amount: Int
    try: amount = atol(text)
    except: return Err(String("invalid amount"))
    if amount < 0: return Err(String("negative amount"))
    return Ok(amount)

def add(var total: Int, var amount: Int) -> Int: return total + amount
def total(var amounts: List[Int]) -> Int:
    return pipeline(amounts^).fold_left(add, 0).get()
def receipt(var amount: Int, var shipping: Int, var tax: Int) -> String:
    return "total: " + String(amount + shipping + tax)

def checkout(var amounts: List[String]) raises WorkflowTransportFailure -> Result[String, String]:
    return (pipeline(amounts^)
        .raising[WorkflowTransportFailure]()
        .traverse[ResultFamily[String]](parse)
        .map(total)
        .map_n((Result[Int, String](Ok(5)), Result[Int, String](Ok(2))), receipt)
        .get())

def main() raises:
    var accepted: Result[String, String]
    try: accepted = checkout(List[String](["12", "15"]))
    except _: raise Error("unexpected transport failure")
    assert_equal(accepted._ok().value, "total: 34")
    print(accepted._ok().value)

    var rejected: Result[String, String]
    try: rejected = checkout(List[String](["12", "invalid", "15"]))
    except _: raise Error("unexpected transport failure")
    assert_equal(rejected._err().value, "invalid amount")
    print(rejected._err().value)

    var status = 0
    try: _ = checkout(List[String](["offline"]))
    except error: status = error.status
    assert_equal(status, 503)
    print("transport:", status)
