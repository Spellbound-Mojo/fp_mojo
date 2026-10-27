"""Parse, collect, total and combine with one native error selection."""
from fp.functions import pipeline
from fp.algebra import ResultFamily
from fp.data import Result, Ok, Err, ok
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
def explain(var error: String) -> String: return error^

def add_parsed(var total: Int, var text: String) raises WorkflowTransportFailure -> Result[Int, String]:
    def add_amount(var amount: Int) {total} -> Int: return total + amount
    return pipeline(parse(text^)).map(add_amount).get()

def checkout_fold(var amounts: List[String]) raises WorkflowTransportFailure -> Result[String, String]:
    return (pipeline(amounts^)
        .raising[WorkflowTransportFailure]()
        .fold_effect[ResultFamily[String]](0).run(add_parsed)
        .map_n((ok[String](5), ok[String](2)), receipt)
        .get())

def checkout(var amounts: List[String]) raises WorkflowTransportFailure -> Result[String, String]:
    return (pipeline(amounts^)
        .raising[WorkflowTransportFailure]()
        .traverse(parse)
        .map(total)
        .map_n((ok[String](5), ok[String](2)), receipt)
        .get())

def main() raises:
    var accepted: Result[String, String]
    try: accepted = checkout(List[String](["12", "15"]))
    except _: raise Error("unexpected transport failure")
    var accepted_text = accepted^.value_or(explain)
    assert_equal(accepted_text, "total: 34")
    var folded: Result[String, String]
    try: folded = checkout_fold(List[String](["12", "15"]))
    except _: raise Error("unexpected transport failure")
    assert_equal(folded^.value_or(explain), accepted_text)
    print(accepted_text)

    var rejected: Result[String, String]
    try: rejected = checkout(List[String](["12", "invalid", "15"]))
    except _: raise Error("unexpected transport failure")
    var rejected_text = rejected^.value_or(explain)
    assert_equal(rejected_text, "invalid amount")
    print(rejected_text)

    var status = 0
    try: _ = checkout(List[String](["offline"]))
    except error: status = error.status
    assert_equal(status, 503)
    print("transport:", status)
