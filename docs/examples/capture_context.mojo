"""Reuse one error context for ordinary, bound and stateful native calls."""
from fp.data import Capture

def ready() -> String: return "ready"
def debit(mut balance: Int, var amount: Int) raises Int -> Int:
    balance -= amount
    if balance < 0: raise balance
    return balance

def main():
    var capture = Capture[Int]()
    print(capture.run(ready)._ok().value)
    var balance = 10
    var paid = capture.mutable(balance).take(4).run(debit)
    print("paid:", paid._ok().value)
    var refused = capture.mutable(balance).take(8).run(debit)
    print("declined:", refused._err().value)
    var account = capture.stateful(debit, 20)
    print("saved state:", account.run(5)._ok().value)
