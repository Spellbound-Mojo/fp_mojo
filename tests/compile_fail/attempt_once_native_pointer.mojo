# error: ThunkContract
from fp.data import attempt_once
def native() -> Int: return 1
def main():
    var callback: def() thin -> Int = native
    _ = attempt_once(callback)
