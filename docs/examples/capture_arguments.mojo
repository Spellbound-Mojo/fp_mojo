"""Bind several owned arguments before capturing a native call."""
from fp.data import Capture
from std.testing import assert_equal

def invoice(var name: String, var units: Int, var price: Int, var shipping: Int) raises String -> String:
    if units < 0: raise String("invalid quantity")
    return name + ": " + String(units * price + shipping)

def explain(var error: String) -> String: return error^

def main() raises:
    var accepted = Capture[String].args(String("books"), 3, 12, 5).run(invoice)
    var receipt = accepted^.value_or(explain)
    assert_equal(receipt, "books: 41")
    print(receipt)
    var rejected = Capture[String].args(String("books"), -1, 12, 5).run(invoice)
    var message = rejected^.value_or(explain)
    assert_equal(message, "invalid quantity")
    print(message)
