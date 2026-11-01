# error: cannot call function that may raise
from fp.functions import pipeline, partial

def fail(offset: Int, value: Int) raises Int -> Int: raise offset + value
def wrong() raises String:
    var callback = partial(fail, 1)
    _ = pipeline(2).raising[String]().then(callback).get()
def main():
    try: wrong()
    except _: pass
