"""Gather native effects without repeating their family or payload types."""
from fp.data import Result, Ok, Err
from fp.functions import pipeline
from std.testing import assert_equal

def parse(var text: String) -> Result[Int, String]:
    try: return Ok(atol(text))
    except: return Err(String("invalid quantity"))

def total(var values: List[Int]) -> Int:
    var result = 0
    for value in values: result += value
    return result

def main() raises:
    var amount = pipeline(List[String](["12", "3"])).traverse(parse).map(total).get_or(0)
    assert_equal(amount, 15)
    print("total:", amount)
    var reason = pipeline(List[String](["12", "bad", "3"])).traverse(parse).swap().get_or("")
    assert_equal(reason, "invalid quantity")
    print("error:", reason)
    var available = List[Optional[Int]]([Optional(2), Optional(4)])
    var gathered = pipeline(available^).sequence().get_or(List[Int]())
    assert_equal(gathered, [2, 4])
    print("gathered:", gathered[0], gathered[1])
