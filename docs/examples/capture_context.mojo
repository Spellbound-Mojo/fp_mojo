"""Reuse one error context for ordinary, bound and stateful native calls."""
from fp.data import Capture
from fp.callables import mut_ref
from fp.functions import pipeline

def ready() -> String: return "ready"
def debit(mut balance: Int, var amount: Int) raises Int -> Int:
    balance -= amount
    if balance < 0: raise balance
    return balance

def main():
    var capture = Capture[Int]()
    print(capture.run(ready).get_or(String()))
    var balance = 10
    var paid = capture.mutable(balance).take(4).run(debit)
    print("paid:", paid^.get_or(0))
    var refused = capture.mutable(balance).take(8).run(debit)
    print("declined:", refused^.swap().get_or(0))
    var account = capture.stateful(debit, 20)
    print("saved state:", account.run(5).get_or(0))
    var payments = pipeline[Int]([5, 20, 100]).traverse(mut_ref(account)).get()
    print("traversal error:", payments^.swap().get_or(0), "; state:", account.state())
